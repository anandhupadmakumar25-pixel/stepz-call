import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/quotation_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/receipt_voucher_model.dart';
import '../models/document_template_model.dart';

class BillingProvider extends ChangeNotifier {
  List<QuotationModel> _quotations = [];
  List<InvoiceModel> _invoices = [];
  List<ReceiptVoucherModel> _receiptVouchers = [];
  List<ProductModel> _products = [];
  List<DocumentTemplateModel> _templates = [];
  QuotationModel? _selectedQuotation;
  InvoiceModel? _selectedInvoice;
  ReceiptVoucherModel? _selectedReceiptVoucher;
  ReceiptVoucherModel? _lastGeneratedReceipt;
  BillingOverviewModel? _billingOverview;
  bool _isLoading = false;
  String? _errorMessage;

  List<QuotationModel> get quotations => _quotations;
  List<InvoiceModel> get invoices => _invoices;
  List<ReceiptVoucherModel> get receiptVouchers => _receiptVouchers;
  List<ProductModel> get products => _products;
  List<DocumentTemplateModel> get templates => _templates;
  List<DocumentTemplateModel> templatesForType(String docType) =>
      _templates.where((t) => t.docType == docType && t.isActive).toList();
  DocumentTemplateModel? defaultTemplateFor(String docType, {String? branchId}) {
    final list = templatesForType(docType);
    if (list.isEmpty) return null;
    if (branchId != null && branchId.isNotEmpty) {
      final branchList = list.where((t) => t.branchId == branchId).toList();
      if (branchList.isNotEmpty) {
        return branchList.firstWhere((t) => t.isDefault, orElse: () => branchList.first);
      }
    }
    return list.firstWhere((t) => t.isDefault, orElse: () => list.first);
  }
  QuotationModel? get selectedQuotation => _selectedQuotation;
  InvoiceModel? get selectedInvoice => _selectedInvoice;
  ReceiptVoucherModel? get selectedReceiptVoucher => _selectedReceiptVoucher;
  ReceiptVoucherModel? get lastGeneratedReceipt => _lastGeneratedReceipt;
  BillingOverviewModel? get billingOverview => _billingOverview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<List<ProductModel>> fetchProducts({String? search}) async {
    try {
      final query = search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : '';
      final res = await ApiClient.get('/billing/products/$query');
      if (res is List) {
        _products = res.map((item) => ProductModel.fromJson(item)).toList();
        notifyListeners();
        return _products;
      }
    } catch (_) {}
    return _products;
  }

  Future<ProductModel?> saveProduct({
    required String name,
    required double unitPrice,
    double taxPercent = 18.0,
    String unit = 'unit',
    String description = '',
  }) async {
    try {
      final res = await ApiClient.post('/billing/products/', {
        'name': name,
        'unit_price': unitPrice,
        'tax_percent': taxPercent,
        'unit': unit,
        'description': description,
      });
      final p = ProductModel.fromJson(res);
      final idx = _products.indexWhere((it) => it.id == p.id || it.name.toLowerCase() == p.name.toLowerCase());
      if (idx != -1) {
        _products[idx] = p;
      } else {
        _products.add(p);
      }
      notifyListeners();
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchQuotations({String? leadId, String? status, String? dateFrom, String? dateTo}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (leadId != null && leadId.isNotEmpty) {
        params.add('lead_id=$leadId');
      }
      if (status != null && status.isNotEmpty && status != 'ALL') params.add('status=$status');
      if (dateFrom != null && dateFrom.isNotEmpty) params.add('date_from=$dateFrom');
      if (dateTo != null && dateTo.isNotEmpty) params.add('date_to=$dateTo');

      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('/billing/quotations/$query');
      if (res is List) {
        _quotations = res.map((item) => QuotationModel.fromJson(item)).toList();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<QuotationModel?> fetchQuotationDetail(String quotationId) async {
    try {
      final res = await ApiClient.get('/billing/quotations/$quotationId/');
      _selectedQuotation = QuotationModel.fromJson(res);
      notifyListeners();
      return _selectedQuotation;
    } catch (e) {
      return null;
    }
  }

  Future<QuotationModel?> createQuotation(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/billing/quotations/', data);
      final newQuote = QuotationModel.fromJson(res);
      _quotations.insert(0, newQuote);
      _isLoading = false;
      notifyListeners();
      // Also refresh product catalog in background as newly entered items were saved
      fetchProducts();
      return newQuote;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<QuotationModel?> updateQuotation(String quotationId, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.patch('/billing/quotations/$quotationId/', data);
      final updated = QuotationModel.fromJson(res);
      final idx = _quotations.indexWhere((q) => q.id == quotationId);
      if (idx != -1) {
        _quotations[idx] = updated;
      }
      if (_selectedQuotation?.id == quotationId) {
        _selectedQuotation = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<QuotationModel?> approveOrRejectQuotation(
    String quotationId, {
    required String action,
    String rejectionReason = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        '/billing/quotations/$quotationId/approval/',
        {
          'action': action,
          if (rejectionReason.isNotEmpty) 'rejection_reason': rejectionReason,
        },
      );
      final updated = QuotationModel.fromJson(res);
      final idx = _quotations.indexWhere((q) => q.id == quotationId);
      if (idx != -1) {
        _quotations[idx] = updated;
      }
      if (_selectedQuotation?.id == quotationId) {
        _selectedQuotation = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteQuotation(String quotationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.delete('/billing/quotations/$quotationId/');
      _quotations.removeWhere((q) => q.id == quotationId);
      if (_selectedQuotation?.id == quotationId) {
        _selectedQuotation = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<InvoiceModel?> convertQuotationToInvoice(
    String quotationId, {
    Map<String, dynamic>? overrideData,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        '/billing/quotations/$quotationId/convert-to-invoice/',
        overrideData ?? {},
      );
      final invoice = InvoiceModel.fromJson(res);
      _invoices.insert(0, invoice);
      final qIdx = _quotations.indexWhere((q) => q.id == quotationId);
      if (qIdx != -1) {
        _quotations[qIdx] = _quotations[qIdx].copyWith(status: 'CONVERTED');
      }
      if (_selectedQuotation?.id == quotationId) {
        _selectedQuotation = _selectedQuotation!.copyWith(status: 'CONVERTED');
      }
      _isLoading = false;
      notifyListeners();
      // Background sync overview & invoices
      fetchBillingOverview();
      fetchInvoices();
      fetchQuotations();
      return invoice;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchInvoices({String? leadId, String? status, String? dateFrom, String? dateTo}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (leadId != null && leadId.isNotEmpty) {
        params.add('lead_id=$leadId');
      }
      if (status != null && status.isNotEmpty && status != 'ALL') params.add('status=$status');
      if (dateFrom != null && dateFrom.isNotEmpty) params.add('date_from=$dateFrom');
      if (dateTo != null && dateTo.isNotEmpty) params.add('date_to=$dateTo');

      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('/billing/invoices/$query');
      if (res is List) {
        _invoices = res.map((item) => InvoiceModel.fromJson(item)).toList();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> createInvoice(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/billing/invoices/', data);
      final newInv = InvoiceModel.fromJson(res);
      _invoices.insert(0, newInv);
      _isLoading = false;
      notifyListeners();
      // Background sync overview & products
      fetchBillingOverview();
      fetchProducts();
      return newInv;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> updateInvoice(String invoiceId, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.patch('/billing/invoices/$invoiceId/', data);
      final updated = InvoiceModel.fromJson(res);
      final idx = _invoices.indexWhere((inv) => inv.id == invoiceId);
      if (idx != -1) {
        _invoices[idx] = updated;
      }
      if (_selectedInvoice?.id == invoiceId) {
        _selectedInvoice = updated;
      }
      _isLoading = false;
      notifyListeners();
      fetchBillingOverview();
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> fetchInvoiceDetail(String invoiceId) async {
    try {
      final res = await ApiClient.get('/billing/invoices/$invoiceId/');
      _selectedInvoice = InvoiceModel.fromJson(res);
      notifyListeners();
      return _selectedInvoice;
    } catch (e) {
      return null;
    }
  }

  Future<bool> recordPayment({
    required String invoiceId,
    required double amount,
    required String paymentMode,
    String? paymentReference,
    String? notes,
    bool generateReceipt = true,
    String? chequeNumber,
    String? bankName,
    String? chequeDate,
    String? receiverName,
    String? accountantName,
    bool hasWatermarkStamp = true,
    bool includePodSlip = false,
    String? podDriverName,
    String? podReceiverName,
    String? podReceiverPhone,
    String? podDeliveryDate,
    String? podCommodity,
    String? templateId,
    Map<String, dynamic>? templateSnapshot,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastGeneratedReceipt = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'amount': amount,
        'payment_mode': paymentMode,
        'payment_reference': paymentReference ?? '',
        'notes': notes ?? '',
        'generate_receipt': generateReceipt,
        'cheque_number': chequeNumber ?? '',
        'bank_name': bankName ?? '',
        if (chequeDate != null) 'cheque_date': chequeDate,
        'receiver_name': receiverName ?? '',
        'accountant_name': accountantName ?? '',
        'has_watermark_stamp': hasWatermarkStamp,
        'include_pod_slip': includePodSlip,
        'pod_driver_name': podDriverName ?? '',
        'pod_receiver_name': podReceiverName ?? '',
        'pod_receiver_phone': podReceiverPhone ?? '',
        if (podDeliveryDate != null) 'pod_delivery_date': podDeliveryDate,
        'pod_commodity': podCommodity ?? '',
        if (templateId != null) 'template': templateId,
        if (templateSnapshot != null && templateSnapshot.isNotEmpty) 'template_snapshot': templateSnapshot,
      };

      final res = await ApiClient.post('/billing/invoices/$invoiceId/record-payment/', payload);
      ReceiptVoucherModel? newVoucher;

      if (res is Map<String, dynamic>) {
        final invJson = res.containsKey('invoice') ? res['invoice'] : res;
        final updatedInv = InvoiceModel.fromJson(invJson);
        final idx = _invoices.indexWhere((inv) => inv.id == invoiceId);
        if (idx != -1) {
          _invoices[idx] = updatedInv;
        }
        if (_selectedInvoice?.id == invoiceId) {
          _selectedInvoice = updatedInv;
        }

        if (res.containsKey('receipt_voucher') && res['receipt_voucher'] != null) {
          newVoucher = ReceiptVoucherModel.fromJson(res['receipt_voucher']);
          _lastGeneratedReceipt = newVoucher;
          _receiptVouchers.insert(0, newVoucher);
        }
      }

      _isLoading = false;
      notifyListeners();
      fetchBillingOverview();
      fetchReceiptVouchers();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchReceiptVouchers({
    String? invoiceId,
    String? quotationId,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (invoiceId != null && invoiceId.isNotEmpty) params.add('invoice_id=$invoiceId');
      if (quotationId != null && quotationId.isNotEmpty) params.add('quotation_id=$quotationId');
      if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
      if (dateFrom != null && dateFrom.isNotEmpty) params.add('date_from=$dateFrom');
      if (dateTo != null && dateTo.isNotEmpty) params.add('date_to=$dateTo');

      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('/billing/receipt-vouchers/$query');
      if (res is List) {
        _receiptVouchers = res.map((item) => ReceiptVoucherModel.fromJson(item)).toList();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ReceiptVoucherModel?> fetchReceiptVoucherDetail(String voucherId) async {
    try {
      final res = await ApiClient.get('/billing/receipt-vouchers/$voucherId/');
      _selectedReceiptVoucher = ReceiptVoucherModel.fromJson(res);
      notifyListeners();
      return _selectedReceiptVoucher;
    } catch (e) {
      return null;
    }
  }

  Future<ReceiptVoucherModel?> createReceiptVoucher(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/billing/receipt-vouchers/', data);
      final newVoucher = ReceiptVoucherModel.fromJson(res);
      _receiptVouchers.insert(0, newVoucher);
      _isLoading = false;
      notifyListeners();
      return newVoucher;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteReceiptVoucher(String voucherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.delete('/billing/receipt-vouchers/$voucherId/');
      _receiptVouchers.removeWhere((v) => v.id == voucherId);
      if (_selectedReceiptVoucher?.id == voucherId) {
        _selectedReceiptVoucher = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchBillingOverview() async {
    try {
      final res = await ApiClient.get('/billing/overview/');
      if (res is Map<String, dynamic>) {
        _billingOverview = BillingOverviewModel.fromJson(res);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchTemplates({String? docType}) async {
    try {
      final query = docType != null && docType.isNotEmpty ? '?doc_type=$docType' : '';
      final res = await ApiClient.get('/billing/templates/$query');
      if (res is List) {
        final loaded = res
            .whereType<Map<String, dynamic>>()
            .map((e) => DocumentTemplateModel.fromJson(e))
            .toList();
        if (docType != null && docType.isNotEmpty) {
          _templates.removeWhere((t) => t.docType == docType);
          _templates.addAll(loaded);
        } else {
          _templates = loaded;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<DocumentTemplateModel?> createTemplate({
    required String name,
    required String docType,
    required TemplateLayoutConfig layout,
    String? branchId,
    bool isDefault = false,
  }) async {
    _errorMessage = null;
    try {
      final res = await ApiClient.post('/billing/templates/', {
        'name': name.trim(),
        'doc_type': docType,
        'branch': (branchId != null && branchId.isNotEmpty) ? branchId : null,
        'is_default': isDefault,
        'layout_json': layout.toJson(),
      });
      final created = DocumentTemplateModel.fromJson(res as Map<String, dynamic>);
      await fetchTemplates();
      return created;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<DocumentTemplateModel?> updateTemplate({
    required String id,
    String? name,
    TemplateLayoutConfig? layout,
    String? branchId,
    bool? isDefault,
  }) async {
    _errorMessage = null;
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name.trim();
      if (layout != null) payload['layout_json'] = layout.toJson();
      if (branchId != null) payload['branch'] = branchId.isEmpty ? null : branchId;
      if (isDefault != null) payload['is_default'] = isDefault;
      final res = await ApiClient.patch('/billing/templates/$id/', payload);
      final updated = DocumentTemplateModel.fromJson(res as Map<String, dynamic>);
      await fetchTemplates();
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteTemplate(String id) async {
    try {
      await ApiClient.delete('/billing/templates/$id/');
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setDefaultTemplate(String id) async {
    try {
      await ApiClient.post('/billing/templates/$id/set-default/', {});
      await fetchTemplates();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
