import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/vehicles_provider.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  int _step = 1;
  final _plateController = TextEditingController();
  final _engineController = TextEditingController();
  final _chassisController = TextEditingController();
  bool _isLoading = false;

  void _nextStep() {
    if (_plateController.text.isNotEmpty) {
      setState(() => _step = 2);
    }
  }

  void _verify() async {
    setState(() => _isLoading = true);
    final result = await ref.read(vehiclesProvider.notifier).verifyAndAddVehicle(
      _plateController.text, 
      _engineController.text, 
      _chassisController.text
    );
    setState(() => _isLoading = false);

    if (result == "Success") {
      setState(() => _step = 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildStepIndicator(),
            const SizedBox(height: 40),
            Expanded(
              child: _step == 1 ? _buildStep1() : _step == 2 ? _buildStep2() : _buildStep3(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _indicatorDot(1),
        _indicatorLine(1),
        _indicatorDot(2),
        _indicatorLine(2),
        _indicatorDot(3),
      ],
    );
  }

  Widget _indicatorDot(int step) {
    bool isCompleted = _step > step;
    bool isActive = _step == step;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive || isCompleted ? const Color(0xFF00FFD1) : const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        boxShadow: isActive ? [
          BoxShadow(
            color: const Color(0xFF00FFD1).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Center(
        child: isCompleted 
          ? const Icon(Icons.check, size: 18, color: Colors.black)
          : Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white24,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _indicatorLine(int step) {
    bool isCompleted = _step > step;
    return Container(
      width: 40,
      height: 2,
      color: isCompleted ? const Color(0xFF00FFD1) : const Color(0xFF1E1E1E),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Vehicle Registration", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Enter your vehicle's license plate number to begin.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        const SizedBox(height: 40),
        _buildTextField(_plateController, 'License Plate', 'e.g. MP04AB1234', Icons.badge, true),
        const Spacer(),
        _buildActionButton("Continue", _nextStep),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Identity Verification", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Please provide engine and chassis details for verification.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        const SizedBox(height: 40),
        _buildTextField(_engineController, 'Engine Number', 'Last 5 digits', Icons.engineering),
        const SizedBox(height: 20),
        _buildTextField(_chassisController, 'Chassis Number', 'Last 5 digits', Icons.minor_crash),
        const Spacer(),
        _buildActionButton("Verify & Add Vehicle", _verify, isLoading: _isLoading),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF00FFD1).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check_circle_rounded, color: Color(0xFF00FFD1), size: 80),
          ),
        ),
        const SizedBox(height: 32),
        const Text("Registration Complete!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          "Your vehicle ${_plateController.text} has been successfully added to your account.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
        const SizedBox(height: 60),
        _buildActionButton("Go to Map", () => context.go('/map')),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, [bool uppercase = false]) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          prefixIcon: Icon(icon, color: const Color(0xFF00FFD1), size: 20),
          border: InputBorder.none,
          floatingLabelStyle: const TextStyle(color: Color(0xFF00FFD1)),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, {bool isLoading = false}) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00FFD1),
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        disabledBackgroundColor: Colors.white.withOpacity(0.1),
      ),
      child: isLoading 
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
        : Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    );
  }
}

