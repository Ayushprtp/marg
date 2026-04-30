import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;
  final Function(PaymentSuccessResponse) handlePaymentSuccess;
  final Function(PaymentFailureResponse) handlePaymentError;
  final Function(ExternalWalletResponse) handleExternalWallet;

  PaymentService({
    required this.handlePaymentSuccess,
    required this.handlePaymentError,
    required this.handleExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);
  }

  void openCheckout({
    required double amount, 
    required String contact, 
    required String email,
    required String name,
    required String description,
  }) {
    var options = {
      'key': 'rzp_test_YOUR_KEY_HERE', // TODO: Use actual key from env
      'amount': (amount * 100).toInt(), // amount in paisa
      'name': name,
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
      },
      'theme': {
        'color': '#00FF87'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
