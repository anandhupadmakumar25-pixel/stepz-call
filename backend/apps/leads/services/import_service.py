import csv
import io
import openpyxl
from django.db import transaction
from django.utils import timezone
from apps.core.phone_utils import normalize_phone_number
from apps.leads.models import ImportBatch, ImportRowError, Lead, PermanentPhoneNumberRegistry

class LeadImportService:
    @staticmethod
    def parse_file(file_obj, filename: str) -> list[dict]:
        """
        Reads CSV or XLSX and returns a list of dictionaries.
        """
        lower_name = filename.lower()
        rows = []

        if lower_name.endswith('.csv'):
            content = file_obj.read()
            if isinstance(content, bytes):
                # Try UTF-8, fallback to latin-1
                try:
                    text = content.decode('utf-8-sig')
                except UnicodeDecodeError:
                    text = content.decode('latin-1')
            else:
                text = content
            reader = csv.DictReader(io.StringIO(text))
            for r in reader:
                # Strip keys and values
                clean_row = {str(k).strip(): str(v).strip() if v is not None else '' for k, v in r.items() if k}
                rows.append(clean_row)

        elif lower_name.endswith('.xlsx'):
            wb = openpyxl.load_workbook(file_obj, data_only=True)
            sheet = wb.active
            header = []
            for i, row in enumerate(sheet.iter_rows(values_only=True)):
                if i == 0:
                    header = [str(cell).strip() if cell is not None else f"col_{idx}" for idx, cell in enumerate(row)]
                else:
                    if not any(row):
                        continue
                    row_dict = {}
                    for idx, cell in enumerate(row):
                        if idx < len(header):
                            row_dict[header[idx]] = str(cell).strip() if cell is not None else ''
                    rows.append(row_dict)
        else:
            raise ValueError("Unsupported file format. Please upload .csv or .xlsx file.")

        return rows

    @classmethod
    def preview_import(cls, company, uploaded_by, file_obj, filename: str, column_mapping: dict = None) -> ImportBatch:
        """
        Parses file, evaluates validation, duplicates, and permanent registry blocks.
        Saves staging data in ImportBatch for admin preview.
        """
        raw_rows = cls.parse_file(file_obj, filename)
        if not raw_rows:
            raise ValueError("The uploaded file contains no data rows.")

        # Default mapping if none provided
        if not column_mapping:
            headers = list(raw_rows[0].keys())
            column_mapping = cls.guess_column_mapping(headers)

        batch = ImportBatch.objects.create(
            company=company,
            uploaded_by=uploaded_by,
            file_name=filename,
            total_rows=len(raw_rows),
            status='PENDING'
        )

        seen_in_file = set()
        valid_new_count = 0
        duplicate_in_file_count = 0
        permanently_blocked_count = 0
        previously_registered_count = 0
        invalid_rows_count = 0

        # Query existing permanent registry and active leads for this company
        existing_permanently_blocked = set(
            PermanentPhoneNumberRegistry.objects.filter(company=company)
            .values_list('normalized_phone', flat=True)
        )
        existing_active_leads = set(
            Lead.objects.filter(company=company)
            .values_list('normalized_phone', flat=True)
        )

        staging_data = []
        errors_to_create = []

        default_country = company.default_country_iso or 'IN'

        for idx, row in enumerate(raw_rows, start=1):
            name_val = row.get(column_mapping.get('name', 'Name'), '').strip()
            phone_val = row.get(column_mapping.get('phone', 'Phone'), '').strip()
            email_val = row.get(column_mapping.get('email', 'Email'), '').strip()
            city_val = row.get(column_mapping.get('city', 'City'), '').strip()
            state_val = row.get(column_mapping.get('state', 'State'), '').strip()

            if not name_val or not phone_val:
                invalid_rows_count += 1
                errors_to_create.append(ImportRowError(
                    import_batch=batch,
                    row_number=idx,
                    raw_name=name_val,
                    raw_phone=phone_val,
                    error_type='MISSING_REQUIRED',
                    details="Customer name or phone number is missing."
                ))
                continue

            normalized_phone, is_valid, err_msg = normalize_phone_number(phone_val, default_country)
            if not is_valid:
                invalid_rows_count += 1
                errors_to_create.append(ImportRowError(
                    import_batch=batch,
                    row_number=idx,
                    raw_name=name_val,
                    raw_phone=phone_val,
                    error_type='INVALID_NUMBER',
                    details=f"Invalid phone number: {err_msg}"
                ))
                continue

            if normalized_phone in seen_in_file:
                duplicate_in_file_count += 1
                errors_to_create.append(ImportRowError(
                    import_batch=batch,
                    row_number=idx,
                    raw_name=name_val,
                    raw_phone=phone_val,
                    error_type='DUPLICATE_IN_FILE',
                    details=f"Duplicate phone number {normalized_phone} within this file."
                ))
                continue

            seen_in_file.add(normalized_phone)

            # Check Permanent Blocking Invariant:
            if normalized_phone in existing_permanently_blocked:
                permanently_blocked_count += 1
                errors_to_create.append(ImportRowError(
                    import_batch=batch,
                    row_number=idx,
                    raw_name=name_val,
                    raw_phone=phone_val,
                    error_type='PERMANENTLY_BLOCKED',
                    details=f"Phone number {normalized_phone} is permanently blocked because it was previously assigned in this company."
                ))
                continue

            # Check if active lead already exists in DB
            if normalized_phone in existing_active_leads:
                previously_registered_count += 1
                errors_to_create.append(ImportRowError(
                    import_batch=batch,
                    row_number=idx,
                    raw_name=name_val,
                    raw_phone=phone_val,
                    error_type='EXISTING_IN_DB',
                    details=f"Phone number {normalized_phone} already exists in the company lead directory."
                ))
                continue

            # Valid new record
            valid_new_count += 1
            staging_data.append({
                'row_number': idx,
                'name': name_val,
                'raw_phone': phone_val,
                'normalized_phone': normalized_phone,
                'email': email_val,
                'city': city_val,
                'state': state_val,
            })

        ImportRowError.objects.bulk_create(errors_to_create)

        batch.valid_new_count = valid_new_count
        batch.duplicate_in_file_count = duplicate_in_file_count
        batch.permanently_blocked_count = permanently_blocked_count
        batch.previously_registered_count = previously_registered_count
        batch.invalid_rows_count = invalid_rows_count
        batch.staging_data = staging_data
        batch.save()

        return batch

    @classmethod
    def confirm_import(cls, batch_id, company, confirmed_by, branch_id=None, category_id=None) -> int:
        """
        Commits all valid staged leads from preview into real Lead records in DB.
        """
        from apps.leads.models import Branch, LeadCategory
        with transaction.atomic():
            batch = ImportBatch.objects.select_for_update().filter(id=batch_id, company=company).first()
            if not batch:
                raise ValueError("Import batch not found.")
            if batch.status != 'PENDING':
                raise ValueError(f"Batch has already been {batch.status}.")

            branch = None
            if branch_id:
                branch = Branch.objects.filter(id=branch_id, company=company).first()

            category = None
            if category_id:
                category = LeadCategory.objects.filter(id=category_id, company=company).first()

            leads_to_create = []
            for item in batch.staging_data:
                names = item['name'].split(' ', 1)
                first_name = names[0]
                last_name = names[1] if len(names) > 1 else ''

                leads_to_create.append(Lead(
                    company=company,
                    first_name=first_name,
                    last_name=last_name,
                    raw_phone=item['raw_phone'],
                    normalized_phone=item['normalized_phone'],
                    email=item.get('email', ''),
                    city=item.get('city', ''),
                    state=item.get('state', ''),
                    branch=branch,
                    category=category,
                    source=f"IMPORT_{batch.file_name}",
                    import_batch=batch,
                    status='UNASSIGNED',
                    is_assigned_ever=False,
                ))

            Lead.objects.bulk_create(leads_to_create)
            batch.status = 'CONFIRMED'
            batch.save()

            return len(leads_to_create)

    @staticmethod
    def guess_column_mapping(headers: list[str]) -> dict:
        mapping = {}
        for h in headers:
            lh = h.lower().replace('_', '').replace(' ', '')
            if 'phone' in lh or 'mobile' in lh or 'contact' in lh or 'cell' in lh:
                if 'phone' not in mapping:
                    mapping['phone'] = h
            elif 'name' in lh or 'customer' in lh or 'client' in lh:
                if 'name' not in mapping:
                    mapping['name'] = h
            elif 'email' in lh or 'mail' in lh:
                if 'email' not in mapping:
                    mapping['email'] = h
            elif 'city' in lh or 'town' in lh:
                if 'city' not in mapping:
                    mapping['city'] = h
            elif 'state' in lh or 'province' in lh:
                if 'state' not in mapping:
                    mapping['state'] = h

        # Fallbacks if not detected
        if 'phone' not in mapping and headers:
            mapping['phone'] = headers[0]
        if 'name' not in mapping and len(headers) > 1:
            mapping['name'] = headers[1]
        return mapping
