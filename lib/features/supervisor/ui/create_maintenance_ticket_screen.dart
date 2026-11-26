import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../driver/providers/driver_language_provider.dart';
import '../providers/supervisor_provider.dart';
import '../services/supervisor_print_service.dart';

class CreateMaintenanceTicketScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bus;

  const CreateMaintenanceTicketScreen({super.key, required this.bus});

  @override
  ConsumerState<CreateMaintenanceTicketScreen> createState() => _CreateMaintenanceTicketScreenState();
}

class _CreateMaintenanceTicketScreenState extends ConsumerState<CreateMaintenanceTicketScreen> {
  final _formKey = GlobalKey<FormState>();

  String _category = 'mechanical';
  String _priority = 'medium';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();

  bool _needsPurchase = true;
  final List<Map<String, dynamic>> _items = [
    {'itemName': '', 'quantity': 1.0, 'unit': 'Nos', 'estimatedPrice': 0.0, 'remarks': ''}
  ];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _odoCtrl.text = widget.bus['current_odometer']?.toString() ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _odoCtrl.dispose();
    _vendorCtrl.dispose();
    super.dispose();
  }

  double get _totalEstPrice {
    double sum = 0;
    for (final it in _items) {
      final q = double.tryParse(it['quantity'].toString()) ?? 0;
      final p = double.tryParse(it['estimatedPrice'].toString()) ?? 0;
      sum += (q * p);
    }
    return sum;
  }

  void _addItem() {
    setState(() {
      _items.add({'itemName': '', 'quantity': 1.0, 'unit': 'Nos', 'estimatedPrice': 0.0, 'remarks': ''});
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submitTicket(bool isTa) async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsPurchase && _items.every((it) => it['itemName'].toString().trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTa ? 'தயவுசெய்து வாங்க வேண்டிய பொருளின் பெயரை உள்ளிடவும்' : 'Please enter the item name to purchase'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final busId = (widget.bus['bus_id'] ?? widget.bus['id'] ?? '').toString();
      final payload = {
        'busId': busId,
        'category': _category,
        'priority': _priority,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'currentOdometer': double.tryParse(_odoCtrl.text.trim()),
        'needsPurchase': _needsPurchase,
        'serviceType': _needsPurchase ? 'outside_vendor' : 'in_house',
        'vendorSuggestion': _vendorCtrl.text.trim(),
        'items': _needsPurchase ? _items.where((it) => it['itemName'].toString().trim().isNotEmpty).toList() : [],
      };

      final result = await ref.read(supervisorActionsProvider.notifier).createMaintenanceTicket(payload);

      if (!mounted) return;

      if (result != null) {
        final ticket = result['ticket'] as Map<String, dynamic>;
        final items = (result['items'] as List<dynamic>?) ?? [];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTa
                  ? 'பராமரிப்பு கோரிக்கை பதிவு செய்யப்பட்டது! (${ticket['ticket_no']})'
                  : 'Maintenance ticket created successfully! (${ticket['ticket_no']})',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );

        // Prompt to print PO Voucher
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.print_rounded, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Text(
                  isTa ? 'PO ரசீது அச்சிடு' : 'Print PO Voucher',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              isTa
                  ? 'டிக்கெட் எண் ${ticket['ticket_no']} வெற்றிகரமாக உருவாக்கப்பட்டது.\n\nபொருட்கள் வாங்குவதற்கு/ஒப்புதலுக்காக இந்த PO வவுச்சரை இப்போதே அச்சிட விரும்புகிறீர்களா?'
                  : 'Ticket ${ticket['ticket_no']} generated successfully.\n\nWould you like to print this Purchase Requisition voucher now for purchase approval?',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: Text(isTa ? 'பிறகு' : 'Later'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                  SupervisorPrintService.printPoVoucher(ticket: ticket, items: items);
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(isTa ? 'இப்போதே அச்சிடு' : 'Print Now'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTa ? 'கோரிக்கையை பதிவு செய்வதில் பிழை' : 'Failed to create maintenance ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(driverLanguageProvider);
    final isTa = currentLang == DriverLanguage.tamil;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(
          isTa
              ? 'புதிய PO டிக்கெட் • Bus ${widget.bus['bus_number']}'
              : 'New Issue / PO • Bus ${widget.bus['bus_number']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bus Info Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus ${widget.bus['bus_number']} (${widget.bus['registration_no'] ?? ''})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          '${isTa ? "ஓட்டுநர்" : "Driver"}: ${widget.bus['driver_name'] ?? (isTa ? "நியமிக்கப்படவில்லை" : "Not Assigned")}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category & Priority
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: isTa ? 'பழுது வகை (Category)' : 'Issue Category',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'mechanical',
                          child: Text(isTa ? '⚙️ இயந்திர பழுது' : '⚙️ Mechanical'),
                        ),
                        DropdownMenuItem(
                          value: 'electrical',
                          child: Text(isTa ? '⚡ மின்சாரம்' : '⚡ Electrical'),
                        ),
                        DropdownMenuItem(
                          value: 'tyre',
                          child: Text(isTa ? '🛞 டயர் / பஞ்சர்' : '🛞 Tyre / Puncture'),
                        ),
                        DropdownMenuItem(
                          value: 'oil_lubricant',
                          child: Text(isTa ? '🛢️ ஆயில் / கிரீஸ்' : '🛢️ Oil / Lube'),
                        ),
                        DropdownMenuItem(
                          value: 'body_glass',
                          child: Text(isTa ? '🛠️ பாடி / கண்ணாடி' : '🛠️ Body / Glass'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(isTa ? 'இதர' : 'Other'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? 'mechanical'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: isTa ? 'முக்கியத்துவம் (Priority)' : 'Priority Level',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'low',
                          child: Text(isTa ? '🟢 குறைவு' : '🟢 Low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text(isTa ? '🟡 சாதாரண' : '🟡 Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text(isTa ? '🟠 முக்கியம்' : '🟠 High'),
                        ),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text(isTa ? '🔴 அவசரம்' : '🔴 Critical'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: isTa ? 'பிரச்சனை தலைப்பு (Issue Title) *' : 'Issue Title *',
                  hintText: isTa ? 'எ.கா. பிரேக் லைனர் தேய்மானம்' : 'e.g., Front Brake Pad Replacement',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isTa ? 'தலைப்பு அவசியம்' : 'Title is required') : null,
              ),

              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isTa ? 'முழு விவரம் (Detailed Description) *' : 'Detailed Description *',
                  hintText: isTa
                      ? 'வண்டியில் என்ன சத்தம் வருகிறது, எந்த பக்கம் பழுது உள்ளது என்பதை விளக்கவும்...'
                      : 'Describe the vehicle issue, symptoms, noise, or damaged parts...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isTa ? 'விவரம் அவசியம்' : 'Description is required') : null,
              ),

              const SizedBox(height: 12),

              // Current Odometer
              TextFormField(
                controller: _odoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isTa ? 'தற்போதைய கி.மீ மீட்டர்' : 'Current Odometer (km)',
                  hintText: '327896',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: 'km',
                ),
              ),

              const SizedBox(height: 18),

              // Need to Buy Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF4338CA)),
                        const SizedBox(width: 8),
                        Text(
                          isTa ? 'பொருட்கள் வாங்க வேண்டுமா? (Purchase Needed?)' : 'Require Spare Parts / Purchase (PO)?',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                    Switch(
                      value: _needsPurchase,
                      activeColor: const Color(0xFF4338CA),
                      onChanged: (v) => setState(() => _needsPurchase = v),
                    ),
                  ],
                ),
              ),

              if (_needsPurchase) ...[
                const SizedBox(height: 16),

                // Requisition Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isTa ? 'வாங்க வேண்டிய பொருட்கள்' : 'Parts / Items to Purchase',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text(isTa ? '+ பொருள் சேர்' : '+ Add Item', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Dynamic Items List
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final it = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: const Color(0xFFEEF2FF),
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: it['itemName']?.toString(),
                                decoration: InputDecoration(
                                  labelText: isTa ? 'பொருளின் பெயர் (Item Name) *' : 'Item / Part Name *',
                                  hintText: isTa ? 'எ.கா. Front Brake Liner Set' : 'e.g. Front Brake Liner Set',
                                  isDense: true,
                                ),
                                onChanged: (v) => it['itemName'] = v,
                              ),
                            ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                onPressed: () => _removeItem(idx),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: it['quantity']?.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: isTa ? 'அளவு (Qty)' : 'Quantity', isDense: true),
                                onChanged: (v) => setState(() => it['quantity'] = double.tryParse(v) ?? 1.0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: it['unit']?.toString() ?? 'Nos',
                                decoration: InputDecoration(labelText: isTa ? 'அலகு' : 'Unit', isDense: true),
                                items: const [
                                  DropdownMenuItem(value: 'Nos', child: Text('Nos')),
                                  DropdownMenuItem(value: 'Set', child: Text('Set')),
                                  DropdownMenuItem(value: 'Ltr', child: Text('Ltr')),
                                  DropdownMenuItem(value: 'Pkt', child: Text('Pkt')),
                                  DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                                ],
                                onChanged: (v) => it['unit'] = v ?? 'Nos',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: it['estimatedPrice']?.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: isTa ? 'தோராய விலை (₹)' : 'Est. Rate (₹)', isDense: true),
                                onChanged: (v) => setState(() => it['estimatedPrice'] = double.tryParse(v) ?? 0.0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // Estimated Total Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTa ? 'மொத்த கொள்முதல் மதிப்பீடு:' : 'Total Estimated Budget:',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3730A3)),
                      ),
                      Text(
                        '₹${_totalEstPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF3730A3)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Vendor Suggestion
                TextFormField(
                  controller: _vendorCtrl,
                  decoration: InputDecoration(
                    labelText: isTa ? 'பரிந்துரைக்கப்படும் கடை/நிறுவனம்' : 'Suggested Store / Vendor',
                    hintText: isTa ? 'எ.கா. Sri Amman Auto Spares, Erode' : 'e.g. Sri Amman Auto Spares, Erode',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _submitting ? null : () => _submitTicket(isTa),
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _submitting
                        ? (isTa ? 'பதிவாகிறது...' : 'Submitting Ticket...')
                        : (isTa ? 'கோரிக்கை & PO வவுச்சர் பதிவு செய்' : 'Submit Ticket & Generate PO Voucher'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
