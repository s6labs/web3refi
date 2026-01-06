import 'package:flutter/material.dart';
import '../../names/registry/registration_controller.dart';
import '../../core/web3refi_base.dart';

/// Multi-step name registration flow widget
///
/// Guides users through the complete name registration process.
///
/// ## Features
///
/// - Step-by-step registration wizard
/// - Name availability checking
/// - Duration selection
/// - Record configuration
/// - Transaction confirmation
/// - Success/failure handling
///
/// ## Usage
///
/// ```dart
/// NameRegistrationFlow(
///   registryAddress: '0x123...',
///   resolverAddress: '0x456...',
///   tld: 'xdc',
///   onComplete: (result) {
///     print('Registered: ${result.name}');
///   },
/// )
/// ```
class NameRegistrationFlow extends StatefulWidget {
  /// Registry contract address
  final String registryAddress;

  /// Resolver contract address
  final String resolverAddress;

  /// Top-level domain (e.g., 'xdc', 'eth')
  final String tld;

  /// Callback when registration completes
  final ValueChanged<RegistrationResult>? onComplete;

  /// Callback when flow is cancelled
  final VoidCallback? onCancel;

  /// Initial name suggestion
  final String? suggestedName;

  /// Hide duration selection (use default)
  final bool hideDurationSelection;

  /// Default registration duration
  final Duration defaultDuration;

  const NameRegistrationFlow({
    Key? key,
    required this.registryAddress,
    required this.resolverAddress,
    required this.tld,
    this.onComplete,
    this.onCancel,
    this.suggestedName,
    this.hideDurationSelection = false,
    this.defaultDuration = const Duration(days: 365),
  }) : super(key: key);

  @override
  State<NameRegistrationFlow> createState() => _NameRegistrationFlowState();
}

class _NameRegistrationFlowState extends State<NameRegistrationFlow> {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  Duration _selectedDuration = const Duration(days: 365);
  final Map<String, String> _records = {};

  bool _isCheckingAvailability = false;
  bool? _isAvailable;
  bool _isRegistering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedName != null) {
      _nameController.text = widget.suggestedName!;
    }
    _selectedDuration = widget.defaultDuration;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final name = '${_nameController.text}.${widget.tld}';

    setState(() {
      _isCheckingAvailability = true;
      _isAvailable = null;
      _error = null;
    });

    try {
      final controller = RegistrationController(
        registryAddress: widget.registryAddress,
        resolverAddress: widget.resolverAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      final available = await controller.isAvailable(name);

      if (!mounted) return;

      setState(() {
        _isAvailable = available;
        _isCheckingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isCheckingAvailability = false;
      });
    }
  }

  Future<void> _register() async {
    final name = '${_nameController.text}.${widget.tld}';
    final userAddress = await Web3Refi.instance.wallet.getAddress();

    setState(() {
      _isRegistering = true;
      _error = null;
    });

    try {
      final controller = RegistrationController(
        registryAddress: widget.registryAddress,
        resolverAddress: widget.resolverAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      final result = await controller.register(
        name: name,
        owner: userAddress,
        duration: _selectedDuration,
        setRecords: _records.isNotEmpty ? _records : null,
      );

      if (!mounted) return;

      widget.onComplete?.call(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isRegistering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: _onStepContinue,
      onStepCancel: _onStepCancel,
      onStepTapped: (step) => setState(() => _currentStep = step),
      controlsBuilder: _buildControls,
      steps: [
        Step(
          title: const Text('Choose Name'),
          content: _buildNameStep(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
        if (!widget.hideDurationSelection)
          Step(
            title: const Text('Select Duration'),
            content: _buildDurationStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
        Step(
          title: const Text('Add Records (Optional)'),
          content: _buildRecordsStep(),
          isActive: _currentStep >= (widget.hideDurationSelection ? 1 : 2),
          state: _currentStep > (widget.hideDurationSelection ? 1 : 2)
              ? StepState.complete
              : StepState.indexed,
        ),
        Step(
          title: const Text('Confirm'),
          content: _buildConfirmStep(),
          isActive: _currentStep >= (widget.hideDurationSelection ? 2 : 3),
          state: StepState.indexed,
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'myname',
            suffixText: '.${widget.tld}',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _isAvailable = null),
        ),
        const SizedBox(height: 16),
        if (_isCheckingAvailability)
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Checking availability...'),
            ],
          ),
        if (_isAvailable == true)
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Available!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        if (_isAvailable == false)
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Not available',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildDurationStep() {
    final durations = [
      Duration(days: 90),
      Duration(days: 365),
      Duration(days: 730),
      Duration(days: 1095),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How long would you like to register this name?'),
        const SizedBox(height: 16),
        ...durations.map((duration) {
          final years = duration.inDays ~/ 365;
          final label = years > 0 ? '$years year${years > 1 ? 's' : ''}' : '${duration.inDays} days';

          return RadioListTile<Duration>(
            title: Text(label),
            value: duration,
            groupValue: _selectedDuration,
            onChanged: (value) => setState(() => _selectedDuration = value!),
          );
        }),
      ],
    );
  }

  Widget _buildRecordsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add optional records to your name:'),
        const SizedBox(height: 16),
        _buildRecordField('email', 'Email', Icons.email),
        const SizedBox(height: 8),
        _buildRecordField('url', 'Website', Icons.link),
        const SizedBox(height: 8),
        _buildRecordField('avatar', 'Avatar URL', Icons.image),
        const SizedBox(height: 8),
        _buildRecordField('com.twitter', 'Twitter', Icons.tag),
        const SizedBox(height: 8),
        _buildRecordField('com.github', 'GitHub', Icons.code),
      ],
    );
  }

  Widget _buildRecordField(String key, String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        if (value.isNotEmpty) {
          _records[key] = value;
        } else {
          _records.remove(key);
        }
      },
    );
  }

  Widget _buildConfirmStep() {
    final name = '${_nameController.text}.${widget.tld}';
    final years = _selectedDuration.inDays ~/ 365;
    final durationText = years > 0 ? '$years year${years > 1 ? 's' : ''}' : '${_selectedDuration.inDays} days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review your registration:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _buildConfirmRow('Name', name),
        _buildConfirmRow('Duration', durationText),
        if (_records.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Records:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ..._records.entries.map((e) => _buildConfirmRow('  ${e.key}', e.value)),
        ],
        if (_isRegistering) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(child: Text('Registering name...')),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final isLastStep = _currentStep == (widget.hideDurationSelection ? 2 : 3);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          if (isLastStep)
            FilledButton(
              onPressed: _isRegistering ? null : _register,
              child: _isRegistering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            )
          else
            FilledButton(
              onPressed: details.onStepContinue,
              child: const Text('Continue'),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: details.onStepCancel,
            child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() async {
    if (_currentStep == 0) {
      // Check availability before continuing
      await _checkAvailability();
      if (_isAvailable == true) {
        setState(() => _currentStep++);
      }
    } else if (_currentStep < (widget.hideDurationSelection ? 2 : 3)) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      widget.onCancel?.call();
    }
  }
}
