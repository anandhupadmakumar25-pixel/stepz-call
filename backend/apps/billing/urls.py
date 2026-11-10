from django.urls import path
from apps.billing.views import (
    ProductListCreateView,
    ProductDetailView,
    QuotationListCreateView,
    QuotationDetailView,
    QuotationConvertToInvoiceView,
    InvoiceListCreateView,
    InvoiceDetailView,
    InvoiceRecordPaymentView,
    BillingOverviewKPIView,
)

urlpatterns = [
    path('overview/', BillingOverviewKPIView.as_view(), name='billing_overview'),
    path('products/', ProductListCreateView.as_view(), name='product_list_create'),
    path('products/<uuid:pk>/', ProductDetailView.as_view(), name='product_detail'),
    path('quotations/', QuotationListCreateView.as_view(), name='quotation_list_create'),
    path('quotations/<uuid:pk>/', QuotationDetailView.as_view(), name='quotation_detail'),
    path('quotations/<uuid:pk>/convert-invoice/', QuotationConvertToInvoiceView.as_view(), name='quotation_convert_invoice'),
    path('quotations/<uuid:pk>/convert-to-invoice/', QuotationConvertToInvoiceView.as_view(), name='quotation_convert_to_invoice'),
    path('invoices/', InvoiceListCreateView.as_view(), name='invoice_list_create'),
    path('invoices/<uuid:pk>/', InvoiceDetailView.as_view(), name='invoice_detail'),
    path('invoices/<uuid:pk>/record-payment/', InvoiceRecordPaymentView.as_view(), name='invoice_record_payment'),
]
