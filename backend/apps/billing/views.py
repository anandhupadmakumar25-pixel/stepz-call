import datetime
from django.utils import timezone
from django.db import transaction
from django.db.models import Sum, Count, Q
from rest_framework import views, status, generics
from rest_framework.response import Response
from apps.accounts.region_utils import resolve_request_country
from apps.billing.fx_utils import get_fx_rates, build_fx_metric
from apps.billing.models import Quotation, Invoice, ReceiptVoucher, Product, DocumentTemplate
from apps.billing.serializers import (
    QuotationSerializer,
    InvoiceSerializer,
    ReceiptVoucherSerializer,
    RecordPaymentSerializer,
    ProductSerializer,
    DocumentTemplateSerializer,
)


def _attach_template_snapshot(data, company, doc_type):
    """
    Resolves the selected DocumentTemplate (or company default for doc_type)
    and snapshots its layout_json onto the document payload.
    """
    if not company:
        return
    tpl_id = data.get('template')
    tpl = None
    if tpl_id:
        tpl = DocumentTemplate.objects.filter(id=tpl_id, company=company, is_active=True).first()
    if not tpl and not data.get('template_snapshot'):
        tpl = DocumentTemplate.objects.filter(company=company, doc_type=doc_type, is_default=True, is_active=True).first()
    if tpl:
        data['template'] = str(tpl.id)
        if not data.get('template_snapshot'):
            data['template_snapshot'] = tpl.layout_json or {}
from apps.billing.utils.number_to_words import amount_to_words_en, amount_to_words_ar
from apps.core.permissions import IsEmployee, IsCompanyAdmin, require_permission, require_any_permission


def _redact_cost_fields(payload, user):
    """
    Server-side security guard: strips internal CST cost and gross margin
    fields from Quotation/Invoice JSON if user lacks 'quotations.view_cost_cst'.
    """
    if user and user.has_permission('quotations.view_cost_cst'):
        return payload

    def _clean_doc(doc):
        if not isinstance(doc, dict):
            return doc
        doc.pop('total_cost', None)
        doc.pop('gross_margin', None)
        if isinstance(doc.get('items'), list):
            cleaned_items = []
            for item in doc['items']:
                if isinstance(item, dict):
                    item = dict(item)
                    item.pop('cst', None)
                    item.pop('cost_price', None)
                    item.pop('cost_sum', None)
                cleaned_items.append(item)
            doc['items'] = cleaned_items
        return doc

    if isinstance(payload, list):
        return [_clean_doc(dict(d)) for d in payload]
    if isinstance(payload, dict):
        return _clean_doc(dict(payload))
    return payload

def generate_quotation_number(company):
    year = datetime.date.today().year
    prefix = f"QT-{year}-"
    latest = Quotation.objects.filter(company=company, quotation_number__startswith=prefix).order_by('-quotation_number').first()
    if latest:
        try:
            num = int(latest.quotation_number.split('-')[-1]) + 1
        except Exception:
            num = Quotation.objects.filter(company=company).count() + 1
    else:
        num = 1
    candidate = f"{prefix}{num:04d}"
    while Quotation.objects.filter(company=company, quotation_number=candidate).exists():
        num += 1
        candidate = f"{prefix}{num:04d}"
    return candidate

def generate_invoice_number(company):
    year = datetime.date.today().year
    prefix = f"INV-{year}-"
    latest = Invoice.objects.filter(company=company, invoice_number__startswith=prefix).order_by('-invoice_number').first()
    if latest:
        try:
            num = int(latest.invoice_number.split('-')[-1]) + 1
        except Exception:
            num = Invoice.objects.filter(company=company).count() + 1
    else:
        num = 1
    candidate = f"{prefix}{num:04d}"
    while Invoice.objects.filter(company=company, invoice_number=candidate).exists():
        num += 1
        candidate = f"{prefix}{num:04d}"
    return candidate

def generate_receipt_voucher_number(company):
    year = datetime.date.today().year
    prefix = f"RV-{year}-"
    latest = ReceiptVoucher.objects.filter(company=company, voucher_number__startswith=prefix).order_by('-voucher_number').first()
    if latest:
        try:
            num = int(latest.voucher_number.split('-')[-1]) + 1
        except Exception:
            num = ReceiptVoucher.objects.filter(company=company).count() + 1
    else:
        num = 1
    candidate = f"{prefix}{num:04d}"
    while ReceiptVoucher.objects.filter(company=company, voucher_number=candidate).exists():
        num += 1
        candidate = f"{prefix}{num:04d}"
    return candidate


class ProductListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('quotations.view', 'quotations.create', 'invoices.view', 'invoices.create')()]
        return [require_any_permission('quotations.create', 'invoices.create')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        qs = Product.objects.filter(company=company, is_active=True)
        search = request.query_params.get('search')
        if search:
            qs = qs.filter(name__icontains=search.strip())
        return Response(ProductSerializer(qs.order_by('name'), many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        name = request.data.get('name', '').strip()
        if not name:
            return Response({"error": "Product name is required."}, status=status.HTTP_400_BAD_REQUEST)

        unit_price = request.data.get('unit_price', 0.00)
        tax_percent = request.data.get('tax_percent', 18.00)
        unit = request.data.get('unit', 'unit')
        description = request.data.get('description', '')

        product, _ = Product.objects.update_or_create(
            company=company,
            name=name,
            defaults={
                'unit_price': unit_price,
                'tax_percent': tax_percent,
                'unit': unit,
                'description': description,
                'is_active': True,
            }
        )
        return Response(ProductSerializer(product).data, status=status.HTTP_201_CREATED)


class ProductDetailView(views.APIView):
    permission_classes = [require_any_permission('quotations.edit', 'invoices.edit')]

    def delete(self, request, pk):
        company = request.user.company
        p = Product.objects.filter(id=pk, company=company).first()
        if not p:
            return Response({"error": "Product not found."}, status=status.HTTP_404_NOT_FOUND)
        p.is_active = False
        p.save(update_fields=['is_active'])
        return Response({"message": "Product removed from catalog."})


class QuotationListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('quotations.view')()]
        return [require_permission('quotations.create')()]

    def get(self, request):
        user = request.user
        company = user.company
        if not company and not user.is_super_admin:
            return Response([])

        if user.is_super_admin:
            qs = Quotation.objects.all()
        elif user.role == 'EMPLOYEE':
            # Strictly individual workspace: employee only sees quotations created by them or for their assigned leads
            qs = Quotation.objects.filter(company=company).filter(
                Q(created_by=user) | Q(lead__assigned_to=user)
            )
        else:
            qs = Quotation.objects.filter(company=company)

        lead_id = request.query_params.get('lead_id') or request.query_params.get('lead')
        if lead_id:
            qs = qs.filter(lead_id=lead_id)
        stat = request.query_params.get('status')
        if stat and stat != 'ALL':
            qs = qs.filter(status=stat)
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return Response(_redact_cost_fields(QuotationSerializer(qs.order_by('-created_at'), many=True).data, request.user))

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data.copy()
        if not data.get('quotation_number'):
            data['quotation_number'] = generate_quotation_number(company)
        if not data.get('currency'):
            data['currency'] = getattr(company, 'currency', 'INR') or 'INR'
        _attach_template_snapshot(data, company, 'QUOTATION')

        items = data.get('items', [])
        if isinstance(items, list):
            cst_sum = 0.0
            for it in items:
                if isinstance(it, dict):
                    cst = float(it.get('cst') or it.get('cost_price') or 0.0)
                    qty = float(it.get('qty') or it.get('quantity') or 1.0)
                    cst_sum += cst * qty
            if cst_sum > 0:
                data['total_cost'] = round(cst_sum, 2)
                gt = float(data.get('grand_total') or 0.0)
                data['gross_margin'] = round(gt - cst_sum, 2)

        serializer = QuotationSerializer(data=data)
        if serializer.is_valid():
            quotation = serializer.save(
                company=company,
                created_by=request.user
            )

            # Auto-save line items to the company's product catalog for automatic search & load next time!
            items = data.get('items', [])
            if isinstance(items, list):
                for it in items:
                    if isinstance(it, dict):
                        if it.get('row_type') == 'SECTION_TITLE':
                            continue
                        p_name = (it.get('description') or it.get('name') or '').strip()
                        p_code = (it.get('item_code') or it.get('code') or '').strip()
                        rate = it.get('unit_price') or it.get('rate')
                        tax = it.get('tax_percent') or 18.0
                        if p_name and rate is not None:
                            try:
                                defaults = {
                                    'unit_price': rate,
                                    'tax_percent': tax,
                                    'is_active': True,
                                }
                                if p_code:
                                    defaults['item_code'] = p_code
                                Product.objects.update_or_create(
                                    company=company,
                                    name=p_name,
                                    defaults=defaults,
                                )
                            except Exception:
                                pass

            return Response(QuotationSerializer(quotation).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class QuotationDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('quotations.view')()]
        if self.request.method == 'DELETE':
            return [require_permission('quotations.delete')()]
        return [require_permission('quotations.edit')()]

    def get(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or quote.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only view quotations created by you or for your leads."}, status=status.HTTP_403_FORBIDDEN)

        return Response(_redact_cost_fields(QuotationSerializer(quote).data, request.user))

    def patch(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or quote.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only edit quotations created by you."}, status=status.HTTP_403_FORBIDDEN)

        data = request.data.copy()
        if data.get('template') and not data.get('template_snapshot'):
            _attach_template_snapshot(data, quote.company, 'QUOTATION')
        serializer = QuotationSerializer(quote, data=data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or quote.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if not (user.is_company_admin or (user.role == 'EMPLOYEE' and quote.created_by_id == user.id)):
            return Response({"error": "Permission denied."}, status=status.HTTP_403_FORBIDDEN)

        quote.delete()
        return Response({"message": "Quotation deleted successfully."})


class QuotationConvertToInvoiceView(views.APIView):
    permission_classes = [require_permission('quotations.convert_to_invoice')]

    def post(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or quote.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only convert your own quotations."}, status=status.HTTP_403_FORBIDDEN)

        existing_invoice = Invoice.objects.filter(quotation=quote).first()
        if quote.status == 'CONVERTED' or existing_invoice:
            return Response(
                {
                    "error": "Quotation has already been converted to an invoice.",
                    "invoice_id": str(existing_invoice.id) if existing_invoice else None,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        items = request.data.get('items', quote.items)
        custom_columns = request.data.get('custom_columns', quote.custom_columns or [])
        subtotal = request.data.get('subtotal', quote.subtotal)
        tax_amount = request.data.get('tax_amount', quote.tax_amount)
        discount_amount = request.data.get('discount_amount', quote.discount_amount)
        grand_total = request.data.get('grand_total', quote.grand_total)
        due_date = request.data.get('due_date') or (datetime.date.today() + datetime.timedelta(days=15))
        notes = request.data.get('notes', quote.notes)

        invoice_num = generate_invoice_number(company)
        default_inv_tpl = DocumentTemplate.objects.filter(
            company=company, doc_type='INVOICE', is_default=True, is_active=True
        ).first()
        invoice = Invoice.objects.create(
            company=company,
            quotation=quote,
            lead=quote.lead,
            branch=quote.branch,
            invoice_number=invoice_num,
            customer_name=quote.customer_name,
            customer_phone=quote.customer_phone,
            customer_email=quote.customer_email,
            customer_address=quote.customer_address,
            client_code=quote.client_code,
            sales_rep_name=quote.sales_rep_name,
            incoterms=quote.incoterms,
            location=quote.location,
            contact_person=quote.contact_person,
            cr_number=quote.cr_number,
            currency=quote.currency,
            created_by=request.user,
            due_date=due_date,
            items=items,
            custom_columns=custom_columns,
            subtotal=subtotal,
            tax_amount=tax_amount,
            discount_amount=discount_amount,
            grand_total=grand_total,
            total_cost=quote.total_cost,
            gross_margin=quote.gross_margin,
            hide_cost_in_pdf=quote.hide_cost_in_pdf,
            payment_status='PENDING',
            notes=notes,
            terms_and_conditions=quote.terms_and_conditions,
            template=default_inv_tpl,
            template_snapshot=default_inv_tpl.layout_json if default_inv_tpl else {},
        )
        quote.status = 'CONVERTED'
        quote.save(update_fields=['status'])

        return Response(InvoiceSerializer(invoice).data, status=status.HTTP_201_CREATED)


class InvoiceListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('invoices.view')()]
        return [require_permission('invoices.create')()]

    def get(self, request):
        user = request.user
        company = user.company
        if not company and not user.is_super_admin:
            return Response([])

        if user.is_super_admin:
            qs = Invoice.objects.all()
        elif user.role == 'EMPLOYEE':
            # Strictly individual workspace: employee only sees invoices created by them or for their assigned leads
            qs = Invoice.objects.filter(company=company).filter(
                Q(created_by=user) | Q(lead__assigned_to=user)
            )
        else:
            qs = Invoice.objects.filter(company=company)

        lead_id = request.query_params.get('lead_id') or request.query_params.get('lead')
        if lead_id:
            qs = qs.filter(lead_id=lead_id)
        stat = request.query_params.get('status')
        if stat and stat != 'ALL':
            qs = qs.filter(payment_status=stat)
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return Response(_redact_cost_fields(InvoiceSerializer(qs.order_by('-created_at'), many=True).data, request.user))

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data.copy()
        if not data.get('invoice_number'):
            data['invoice_number'] = generate_invoice_number(company)
        curr = data.get('currency') or getattr(company, 'currency', 'INR') or 'INR'
        data['currency'] = curr
        _attach_template_snapshot(data, company, 'INVOICE')

        gt = float(data.get('grand_total') or 0.0)
        if not data.get('amount_in_words_en') and gt:
            data['amount_in_words_en'] = amount_to_words_en(gt, curr)
        if not data.get('amount_in_words_ar') and gt:
            data['amount_in_words_ar'] = amount_to_words_ar(gt, curr)

        items = data.get('items', [])
        if isinstance(items, list):
            cst_sum = 0.0
            for it in items:
                if isinstance(it, dict):
                    cst = float(it.get('cst') or it.get('cost_price') or 0.0)
                    qty = float(it.get('qty') or it.get('quantity') or 1.0)
                    cst_sum += cst * qty
            if cst_sum > 0:
                data['total_cost'] = round(cst_sum, 2)
                data['gross_margin'] = round(gt - cst_sum, 2)

        serializer = InvoiceSerializer(data=data)
        if serializer.is_valid():
            inv = serializer.save(
                company=company,
                created_by=request.user
            )

            # Auto-save line items to the company's product catalog
            items = data.get('items', [])
            if isinstance(items, list):
                for it in items:
                    if isinstance(it, dict):
                        if it.get('row_type') == 'SECTION_TITLE':
                            continue
                        p_name = (it.get('description') or it.get('name') or '').strip()
                        p_code = (it.get('item_code') or it.get('code') or '').strip()
                        rate = it.get('unit_price') or it.get('rate')
                        tax = it.get('tax_percent') or 18.0
                        if p_name and rate is not None:
                            try:
                                defaults = {
                                    'unit_price': rate,
                                    'tax_percent': tax,
                                    'is_active': True,
                                }
                                if p_code:
                                    defaults['item_code'] = p_code
                                Product.objects.update_or_create(
                                    company=company,
                                    name=p_name,
                                    defaults=defaults,
                                )
                            except Exception:
                                pass

            return Response(InvoiceSerializer(inv).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class InvoiceDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('invoices.view')()]
        if self.request.method == 'DELETE':
            return [require_permission('invoices.delete')()]
        return [require_permission('invoices.edit')()]

    def get(self, request, pk):
        user = request.user
        company = user.company
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or inv.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and inv.created_by_id != user.id and (not inv.lead or inv.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only view invoices created by you or for your leads."}, status=status.HTTP_403_FORBIDDEN)

        return Response(_redact_cost_fields(InvoiceSerializer(inv).data, request.user))

    def patch(self, request, pk):
        user = request.user
        company = user.company
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or inv.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and inv.created_by_id != user.id and (not inv.lead or inv.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only edit invoices created by you."}, status=status.HTTP_403_FORBIDDEN)

        data = request.data.copy()
        if data.get('template') and not data.get('template_snapshot'):
            _attach_template_snapshot(data, inv.company, 'INVOICE')
        serializer = InvoiceSerializer(inv, data=data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        return self.patch(request, pk)

    def delete(self, request, pk):
        user = request.user
        company = user.company
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and (not company or inv.company_id != company.id):
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if not user.is_company_admin:
            return Response({"error": "Only company admin can delete invoices."}, status=status.HTTP_403_FORBIDDEN)

        inv.delete()
        return Response({"message": "Invoice deleted successfully."})


class InvoiceRecordPaymentView(views.APIView):
    permission_classes = [require_permission('invoices.record_payment')]

    def post(self, request, pk):
        user = request.user
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        company = inv.company or user.company
        if not company:
            from apps.companies.models import Company
            company = Company.objects.first()

        if not user.is_super_admin and inv.company_id and user.company_id and inv.company_id != user.company_id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and inv.created_by_id != user.id and (not inv.lead or inv.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only record payments for your invoices."}, status=status.HTTP_403_FORBIDDEN)

        serializer = RecordPaymentSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        amount = float(serializer.validated_data['amount'])
        mode = serializer.validated_data['payment_mode']
        ref = serializer.validated_data.get('payment_reference', '')
        p_notes = serializer.validated_data.get('notes', '')

        prev_paid = float(inv.amount_paid)
        remaining_balance = max(0.0, float(inv.grand_total) - prev_paid)
        if amount <= 0:
            return Response({"error": "Payment amount must be greater than 0."}, status=status.HTTP_400_BAD_REQUEST)
        if amount > remaining_balance + 0.01:
            return Response(
                {"error": f"Payment amount ({amount:.2f}) exceeds remaining balance ({remaining_balance:.2f})."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        new_paid = prev_paid + amount
        inv.amount_paid = new_paid
        inv.payment_mode = mode
        if ref:
            inv.payment_reference = ref
        if p_notes:
            inv.payment_notes = f"{inv.payment_notes}\n[{datetime.date.today()}]: {p_notes}".strip()

        if new_paid >= float(inv.grand_total):
            inv.payment_status = 'PAID'
        elif new_paid > 0:
            inv.payment_status = 'PARTIAL'

        rem_balance = max(0.0, float(inv.grand_total) - new_paid)

        receipt_data = None
        if serializer.validated_data.get('generate_receipt', True):
            v_num = generate_receipt_voucher_number(company)
            pm = mode.upper().replace(' ', '_')
            if 'CASH' in pm:
                p_choice = 'CASH'
            elif 'CHEQUE' in pm or 'CHECK' in pm:
                p_choice = 'CHEQUE'
            elif 'BANK' in pm or 'TRANSFER' in pm or 'UPI' in pm:
                p_choice = 'BANK_TRANSFER'
            elif 'CARD' in pm:
                p_choice = 'CARD'
            else:
                p_choice = 'ONLINE'

            being_text = f"Payment for Invoice #{inv.invoice_number} - {inv.customer_name}"
            if p_notes:
                being_text += f" ({p_notes})"

            tpl_id = serializer.validated_data.get('template')
            rv_tpl = None
            if tpl_id:
                rv_tpl = DocumentTemplate.objects.filter(id=tpl_id, company=company, is_active=True).first()
            if not rv_tpl:
                rv_tpl = DocumentTemplate.objects.filter(
                    company=company, doc_type='RECEIPT', is_default=True, is_active=True
                ).first()
            rv_snap = serializer.validated_data.get('template_snapshot') or (rv_tpl.layout_json if rv_tpl else {})
            rv = ReceiptVoucher.objects.create(
                company=company,
                created_by=user,
                invoice=inv,
                template=rv_tpl,
                template_snapshot=rv_snap,
                quotation=inv.quotation,
                voucher_number=v_num,
                customer_name=inv.customer_name,
                customer_phone=inv.customer_phone,
                customer_email=inv.customer_email,
                amount=amount,
                currency=inv.currency,
                total_invoice_amount=inv.grand_total,
                previously_paid=prev_paid,
                balance_due=rem_balance,
                amount_in_words_en=amount_to_words_en(amount, inv.currency),
                amount_in_words_ar=amount_to_words_ar(amount, inv.currency),
                payment_method=p_choice,
                cheque_number=serializer.validated_data.get('cheque_number', ''),
                bank_name=serializer.validated_data.get('bank_name', ''),
                cheque_date=serializer.validated_data.get('cheque_date', None),
                payment_reference=ref,
                being=being_text,
                receiver_name=serializer.validated_data.get('receiver_name', '') or getattr(user, 'full_name', '') or getattr(user, 'username', '') or getattr(user, 'email', ''),
                accountant_name=serializer.validated_data.get('accountant_name', ''),
                has_watermark_stamp=serializer.validated_data.get('has_watermark_stamp', True),
                include_pod_slip=serializer.validated_data.get('include_pod_slip', False),
                pod_driver_name=serializer.validated_data.get('pod_driver_name', ''),
                pod_receiver_name=serializer.validated_data.get('pod_receiver_name', ''),
                pod_receiver_phone=serializer.validated_data.get('pod_receiver_phone', ''),
                pod_commodity=serializer.validated_data.get('pod_commodity', ''),
                notes=p_notes,
            )
            receipt_data = ReceiptVoucherSerializer(rv).data

        inv.save()
        resp_data = InvoiceSerializer(inv).data
        if receipt_data:
            resp_data['receipt_voucher'] = receipt_data
        return Response(resp_data, status=status.HTTP_200_OK)


class ReceiptVoucherListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('receipts.view_print')()]
        return [require_permission('receipts.create')()]

    def get(self, request):
        user = request.user
        company = user.company
        if not company and not user.is_super_admin:
            return Response([])

        if user.is_super_admin:
            qs = ReceiptVoucher.objects.all()
        elif user.role == 'EMPLOYEE':
            qs = ReceiptVoucher.objects.filter(company=company).filter(
                Q(created_by=user) | Q(invoice__created_by=user)
            )
        else:
            qs = ReceiptVoucher.objects.filter(company=company)

        invoice_id = request.query_params.get('invoice_id') or request.query_params.get('invoice')
        if invoice_id:
            qs = qs.filter(invoice_id=invoice_id)
        quotation_id = request.query_params.get('quotation_id') or request.query_params.get('quotation')
        if quotation_id:
            qs = qs.filter(quotation_id=quotation_id)
        search = request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(voucher_number__icontains=search.strip()) |
                Q(customer_name__icontains=search.strip()) |
                Q(being__icontains=search.strip())
            )
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return Response(ReceiptVoucherSerializer(qs.order_by('-created_at'), many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data.copy()
        if not data.get('voucher_number'):
            data['voucher_number'] = generate_receipt_voucher_number(company)

        curr = data.get('currency') or getattr(company, 'currency', 'INR') or 'INR'
        data['currency'] = curr
        _attach_template_snapshot(data, company, 'INVOICE')
        amt = data.get('amount', 0.00)
        if not data.get('amount_in_words_en') and amt:
            data['amount_in_words_en'] = amount_to_words_en(amt, curr)
        if not data.get('amount_in_words_ar') and amt:
            data['amount_in_words_ar'] = amount_to_words_ar(amt, curr)

        serializer = ReceiptVoucherSerializer(data=data)
        if serializer.is_valid():
            rv = serializer.save(
                company=company,
                created_by=request.user
            )
            return Response(ReceiptVoucherSerializer(rv).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ReceiptVoucherDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('receipts.view_print')()]
        if self.request.method == 'DELETE':
            return [require_permission('invoices.delete')()]
        return [require_permission('receipts.create')()]

    def get(self, request, pk):
        user = request.user
        company = user.company
        rv = ReceiptVoucher.objects.filter(id=pk).first()
        if not rv:
            return Response({"error": "Receipt voucher not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and rv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        return Response(ReceiptVoucherSerializer(rv).data)

    def patch(self, request, pk):
        user = request.user
        company = user.company
        rv = ReceiptVoucher.objects.filter(id=pk).first()
        if not rv:
            return Response({"error": "Receipt voucher not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and rv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        serializer = ReceiptVoucherSerializer(rv, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        user = request.user
        company = user.company
        rv = ReceiptVoucher.objects.filter(id=pk).first()
        if not rv:
            return Response({"error": "Receipt voucher not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and rv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if not user.is_company_admin:
            return Response({"error": "Only company admin can delete receipt vouchers."}, status=status.HTTP_403_FORBIDDEN)

        rv.delete()
        return Response({"message": "Receipt voucher deleted successfully."})


class BillingOverviewKPIView(views.APIView):
    permission_classes = [require_any_permission('quotations.view', 'invoices.view', 'receipts.view_print')]

    def get(self, request):
        user = request.user
        company = user.company
        if not company and not user.is_super_admin:
            return Response({
                "quotation_count": 0,
                "total_quotation_value": 0.0,
                "invoice_count": 0,
                "total_billed": 0.0,
                "total_collected": 0.0,
                "pending_receivables": 0.0,
                "paid_invoice_count": 0,
                "pending_invoice_count": 0,
            })

        if user.is_super_admin:
            q_qs = Quotation.objects.all()
            inv_qs = Invoice.objects.all()
        elif user.role == 'EMPLOYEE':
            # Scoped strictly to employee's own sales and receivables
            q_qs = Quotation.objects.filter(company=company).filter(
                Q(created_by=user) | Q(lead__assigned_to=user)
            )
            inv_qs = Invoice.objects.filter(company=company).filter(
                Q(created_by=user) | Q(lead__assigned_to=user)
            )
        else:
            q_qs = Quotation.objects.filter(company=company)
            inv_qs = Invoice.objects.filter(company=company)

        _, _, target_currency, target_symbol = resolve_request_country(request, company=company)
        rates = get_fx_rates()

        q_count = q_qs.count()
        q_by_curr = {}
        for row in q_qs.values('currency').annotate(total_val=Sum('grand_total')):
            curr = (row['currency'] or target_currency).strip().upper()
            q_by_curr[curr] = q_by_curr.get(curr, 0.0) + float(row['total_val'] or 0.0)

        inv_count = inv_qs.count()
        billed_by_curr = {}
        paid_by_curr = {}
        pending_by_curr = {}
        for row in inv_qs.values('currency').annotate(
            total_billed=Sum('grand_total'),
            total_paid=Sum('amount_paid'),
        ):
            curr = (row['currency'] or target_currency).strip().upper()
            b = float(row['total_billed'] or 0.0)
            p = float(row['total_paid'] or 0.0)
            billed_by_curr[curr] = billed_by_curr.get(curr, 0.0) + b
            paid_by_curr[curr] = paid_by_curr.get(curr, 0.0) + p
            pending_by_curr[curr] = pending_by_curr.get(curr, 0.0) + max(0.0, b - p)

        total_quote_val, q_fx, q_text, q_items = build_fx_metric(q_by_curr, target_currency, target_symbol, rates)
        total_billed, inv_fx, inv_text, inv_items = build_fx_metric(billed_by_curr, target_currency, target_symbol, rates)
        total_paid, paid_fx, paid_text, paid_items = build_fx_metric(paid_by_curr, target_currency, target_symbol, rates)
        pending_receivables, pend_fx, pend_text, pend_items = build_fx_metric(pending_by_curr, target_currency, target_symbol, rates)

        paid_inv_count = inv_qs.filter(payment_status='PAID').count()
        pending_inv_count = inv_qs.filter(payment_status__in=['PENDING', 'PARTIAL']).count()

        return Response({
            "quotation_count": q_count,
            "total_quotation_value": total_quote_val,
            "invoice_count": inv_count,
            "total_billed": total_billed,
            "total_collected": total_paid,
            "pending_receivables": pending_receivables,
            "paid_invoice_count": paid_inv_count,
            "pending_invoice_count": pending_inv_count,
            "target_currency": target_currency,
            "target_currency_symbol": target_symbol,
            "has_fx_conversion": q_fx or inv_fx or paid_fx or pend_fx,
            "fx_breakdown": {
                "quotations_text": q_text,
                "invoiced_text": inv_text,
                "collected_text": paid_text,
                "pending_text": pend_text,
                "quotations": q_items,
                "invoiced": inv_items,
                "collected": paid_items,
                "pending": pend_items,
            },
        })


class DocumentTemplateListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission(
                'templates.manage',
                'quotations.view', 'quotations.create',
                'invoices.view', 'invoices.create',
                'receipts.view_print', 'receipts.create',
            )()]
        return [require_permission('templates.manage')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([], status=status.HTTP_200_OK)
        qs = DocumentTemplate.objects.filter(company=company, is_active=True)
        doc_type = request.query_params.get('doc_type')
        if doc_type:
            qs = qs.filter(doc_type=doc_type.upper())
        branch_id = request.query_params.get('branch_id')
        if branch_id:
            qs = qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
        return Response(DocumentTemplateSerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)
        serializer = DocumentTemplateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            is_default = serializer.validated_data.get('is_default', False)
            doc_type = serializer.validated_data['doc_type']
            branch = serializer.validated_data.get('branch')
            if is_default:
                DocumentTemplate.objects.filter(
                    company=company, doc_type=doc_type, branch=branch, is_default=True
                ).update(is_default=False)
            tpl = serializer.save(company=company, created_by=request.user)
        return Response(DocumentTemplateSerializer(tpl).data, status=status.HTTP_201_CREATED)


class DocumentTemplateDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission(
                'templates.manage',
                'quotations.view', 'quotations.create',
                'invoices.view', 'invoices.create',
                'receipts.view_print', 'receipts.create',
            )()]
        return [require_permission('templates.manage')()]

    def _get_obj(self, request, pk):
        return DocumentTemplate.objects.filter(id=pk, company=request.user.company).first()

    def get(self, request, pk):
        tpl = self._get_obj(request, pk)
        if not tpl:
            return Response({"error": "Template not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(DocumentTemplateSerializer(tpl).data)

    def patch(self, request, pk):
        tpl = self._get_obj(request, pk)
        if not tpl:
            return Response({"error": "Template not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = DocumentTemplateSerializer(tpl, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            if serializer.validated_data.get('is_default') is True:
                doc_type = serializer.validated_data.get('doc_type', tpl.doc_type)
                branch = serializer.validated_data.get('branch', tpl.branch)
                DocumentTemplate.objects.filter(
                    company=request.user.company, doc_type=doc_type, branch=branch, is_default=True
                ).exclude(id=tpl.id).update(is_default=False)
            tpl = serializer.save()
        return Response(DocumentTemplateSerializer(tpl).data)

    def put(self, request, pk):
        return self.patch(request, pk)

    def delete(self, request, pk):
        tpl = self._get_obj(request, pk)
        if not tpl:
            return Response({"error": "Template not found."}, status=status.HTTP_404_NOT_FOUND)
        tpl.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class DocumentTemplateSetDefaultView(views.APIView):
    permission_classes = [require_permission('templates.manage')]

    def post(self, request, pk):
        tpl = DocumentTemplate.objects.filter(id=pk, company=request.user.company, is_active=True).first()
        if not tpl:
            return Response({"error": "Template not found."}, status=status.HTTP_404_NOT_FOUND)
        with transaction.atomic():
            DocumentTemplate.objects.filter(
                company=request.user.company, doc_type=tpl.doc_type, branch=tpl.branch, is_default=True
            ).update(is_default=False)
            tpl.is_default = True
            tpl.save(update_fields=['is_default', 'updated_at'])
        return Response(DocumentTemplateSerializer(tpl).data)
