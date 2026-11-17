import datetime
from django.utils import timezone
from django.db.models import Sum, Count, Q
from rest_framework import views, status, generics
from rest_framework.response import Response
from apps.billing.models import Quotation, Invoice, ReceiptVoucher, Product
from apps.billing.serializers import (
    QuotationSerializer,
    InvoiceSerializer,
    ReceiptVoucherSerializer,
    RecordPaymentSerializer,
    ProductSerializer,
)
from apps.billing.utils.number_to_words import amount_to_words_en, amount_to_words_ar
from apps.core.permissions import IsEmployee, IsCompanyAdmin

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
    permission_classes = [IsEmployee]

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
    permission_classes = [IsEmployee]

    def delete(self, request, pk):
        company = request.user.company
        p = Product.objects.filter(id=pk, company=company).first()
        if not p:
            return Response({"error": "Product not found."}, status=status.HTTP_404_NOT_FOUND)
        p.is_active = False
        p.save(update_fields=['is_active'])
        return Response({"message": "Product removed from catalog."})


class QuotationListCreateView(views.APIView):
    permission_classes = [IsEmployee]

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
        return Response(QuotationSerializer(qs.order_by('-created_at'), many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data.copy()
        if not data.get('quotation_number'):
            data['quotation_number'] = generate_quotation_number(company)
        if not data.get('currency'):
            data['currency'] = getattr(company, 'currency', 'INR') or 'INR'

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
                        rate = it.get('unit_price') or it.get('rate')
                        tax = it.get('tax_percent') or 18.0
                        if p_name and rate is not None:
                            try:
                                Product.objects.update_or_create(
                                    company=company,
                                    name=p_name,
                                    defaults={
                                        'unit_price': rate,
                                        'tax_percent': tax,
                                        'is_active': True,
                                    }
                                )
                            except Exception:
                                pass

            return Response(QuotationSerializer(quotation).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class QuotationDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and quote.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only view quotations created by you or for your leads."}, status=status.HTTP_403_FORBIDDEN)

        return Response(QuotationSerializer(quote).data)

    def patch(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and quote.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only edit quotations created by you."}, status=status.HTTP_403_FORBIDDEN)

        serializer = QuotationSerializer(quote, data=request.data, partial=True)
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

        if not user.is_super_admin and quote.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if not (user.is_company_admin or (user.role == 'EMPLOYEE' and quote.created_by_id == user.id)):
            return Response({"error": "Permission denied."}, status=status.HTTP_403_FORBIDDEN)

        quote.delete()
        return Response({"message": "Quotation deleted successfully."})


class QuotationConvertToInvoiceView(views.APIView):
    permission_classes = [IsEmployee]

    def post(self, request, pk):
        user = request.user
        company = user.company
        quote = Quotation.objects.filter(id=pk).first()
        if not quote:
            return Response({"error": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and quote.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and quote.created_by_id != user.id and (not quote.lead or quote.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only convert your own quotations."}, status=status.HTTP_403_FORBIDDEN)

        items = request.data.get('items', quote.items)
        custom_columns = request.data.get('custom_columns', quote.custom_columns or [])
        subtotal = request.data.get('subtotal', quote.subtotal)
        tax_amount = request.data.get('tax_amount', quote.tax_amount)
        discount_amount = request.data.get('discount_amount', quote.discount_amount)
        grand_total = request.data.get('grand_total', quote.grand_total)
        due_date = request.data.get('due_date') or (datetime.date.today() + datetime.timedelta(days=15))
        notes = request.data.get('notes', quote.notes)

        invoice_num = generate_invoice_number(company)
        invoice = Invoice.objects.create(
            company=company,
            quotation=quote,
            lead=quote.lead,
            invoice_number=invoice_num,
            customer_name=quote.customer_name,
            customer_phone=quote.customer_phone,
            customer_email=quote.customer_email,
            customer_address=quote.customer_address,
            created_by=request.user,
            due_date=due_date,
            items=items,
            custom_columns=custom_columns,
            subtotal=subtotal,
            tax_amount=tax_amount,
            discount_amount=discount_amount,
            grand_total=grand_total,
            payment_status='PENDING',
            notes=notes,
            terms_and_conditions=quote.terms_and_conditions,
        )
        quote.status = 'CONVERTED'
        quote.save(update_fields=['status'])

        return Response(InvoiceSerializer(invoice).data, status=status.HTTP_201_CREATED)


class InvoiceListCreateView(views.APIView):
    permission_classes = [IsEmployee]

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
        return Response(InvoiceSerializer(qs.order_by('-created_at'), many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data.copy()
        if not data.get('invoice_number'):
            data['invoice_number'] = generate_invoice_number(company)
        curr = data.get('currency') or getattr(company, 'currency', 'INR') or 'INR'
        data['currency'] = curr

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
                        rate = it.get('unit_price') or it.get('rate')
                        tax = it.get('tax_percent') or 18.0
                        if p_name and rate is not None:
                            try:
                                Product.objects.update_or_create(
                                    company=company,
                                    name=p_name,
                                    defaults={
                                        'unit_price': rate,
                                        'tax_percent': tax,
                                        'is_active': True,
                                    }
                                )
                            except Exception:
                                pass

            return Response(InvoiceSerializer(inv).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class InvoiceDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        user = request.user
        company = user.company
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and inv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and inv.created_by_id != user.id and (not inv.lead or inv.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only view invoices created by you or for your leads."}, status=status.HTTP_403_FORBIDDEN)

        return Response(InvoiceSerializer(inv).data)

    def patch(self, request, pk):
        user = request.user
        company = user.company
        inv = Invoice.objects.filter(id=pk).first()
        if not inv:
            return Response({"error": "Invoice not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and inv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and inv.created_by_id != user.id and (not inv.lead or inv.lead.assigned_to_id != user.id):
            return Response({"error": "Unauthorized. You can only edit invoices created by you."}, status=status.HTTP_403_FORBIDDEN)

        serializer = InvoiceSerializer(inv, data=request.data, partial=True)
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

        if not user.is_super_admin and inv.company_id != company.id:
            return Response({"error": "Unauthorized access."}, status=status.HTTP_403_FORBIDDEN)

        if not user.is_company_admin:
            return Response({"error": "Only company admin can delete invoices."}, status=status.HTTP_403_FORBIDDEN)

        inv.delete()
        return Response({"message": "Invoice deleted successfully."})


class InvoiceRecordPaymentView(views.APIView):
    permission_classes = [IsEmployee]

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

            rv = ReceiptVoucher.objects.create(
                company=company,
                created_by=user,
                invoice=inv,
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
    permission_classes = [IsEmployee]

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
    permission_classes = [IsEmployee]

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
    permission_classes = [IsEmployee]

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

        q_agg = q_qs.aggregate(
            count=Count('id'),
            total_val=Sum('grand_total')
        )
        inv_agg = inv_qs.aggregate(
            count=Count('id'),
            total_billed=Sum('grand_total'),
            total_paid=Sum('amount_paid')
        )

        total_billed = float(inv_agg['total_billed'] or 0.0)
        total_paid = float(inv_agg['total_paid'] or 0.0)
        pending_receivables = max(0.0, total_billed - total_paid)

        paid_inv_count = inv_qs.filter(payment_status='PAID').count()
        pending_inv_count = inv_qs.filter(payment_status__in=['PENDING', 'PARTIAL']).count()

        return Response({
            "quotation_count": q_agg['count'] or 0,
            "total_quotation_value": float(q_agg['total_val'] or 0.0),
            "invoice_count": inv_agg['count'] or 0,
            "total_billed": total_billed,
            "total_collected": total_paid,
            "pending_receivables": pending_receivables,
            "paid_invoice_count": paid_inv_count,
            "pending_invoice_count": pending_inv_count,
        })
