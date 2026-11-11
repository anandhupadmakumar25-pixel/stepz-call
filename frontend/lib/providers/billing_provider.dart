import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/quotation_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';

class BillingProvider extends ChangeNotifier {
  List<QuotationModel> _quotations = [];
  List<InvoiceModel> _invoices = [];
  List<ProductModel> _products = [];
  QuotationModel? _selectedQuotation;
  InvoiceModel? _selectedInvoice;
  BillingOverviewModel? _billingOverview;
  bool _isLoading = false;
  String? _errorMessage;

  List<QuotationModel> get quotations => _quotations;
  List<InvoiceModel> get invoices => _invoices;
  List<ProductModel> get products => _products;
  QuotationModel? get selectedQuotation => _selectedQuotation;
  InvoiceModel? get selectedInvoice => _selectedInvoice;
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

  Future<void> fetchQuotations({String? leadId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (leadId != null && leadId.isNotEmpty) {
        params.add('lead_id=$leadId');
      }
      if (status != null && status.isNotEmpty && status != 'ALL') params.add('status=$status');

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

  Future<InvoiceModel?> convertQuotationToInvoice(String quotationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/billing/quotations/$quotationId/convert-to-invoice/', {});
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

  Future<void> fetchInvoices({String? leadId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (leadId != null && leadId.isNotEmpty) {
        params.add('lead_id=$leadId');
      }
      if (status != null && status.isNotEmpty && status != 'ALL') params.add('status=$status');

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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/billing/invoices/$invoiceId/record-payment/', {
        'amount': amount,
        'payment_mode': paymentMode,
        'payment_reference': paymentReference ?? '',
        'notes': notes ?? '',
      });
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
}
