import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../core/money.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../models/food_checkout_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';
import '../services/account_decision_notifier.dart';
import '../services/admin_notification_sender.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';

class DriverDetailScreen extends StatefulWidget {
  final DriverModel driver;

  const DriverDetailScreen({super.key, required this.driver});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;

  DriverModel? _driverState;
  DriverModel get _driver => _driverState ?? widget.driver;

  List<RideModel> _rides = [];
  List<FoodCheckoutModel> _foodOrders = [];
  Map<int, RestaurantModel> _restaurantsMap = {};
  Map<String, RideRequestModel> _rideRequestsById = {};
  Map<String, UserModel> _ridersById = {};
  bool _isLoading = true;
  String? _error;
  bool _activating = false;
  bool _sendingNoti = false;

  bool get _isFoodDriver => _driver.type?.toLowerCase() == 'food';

  String? get _driverPushToken {
    final device = _driver.deviceToken?.trim();
    if (device != null && device.isNotEmpty) return device;
    final fcm = _driver.fcmToken?.trim();
    if (fcm != null && fcm.isNotEmpty) return fcm;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _driverState = widget.driver;
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_isFoodDriver) {
        final orders =
            await _supabaseService.getFoodCheckoutsByDriverId(_driver.id);
        final restaurants = await _supabaseService.getRestaurants();
        setState(() {
          _rides = [];
          _rideRequestsById = {};
          _ridersById = {};
          _foodOrders = orders;
          _restaurantsMap = {for (var r in restaurants) r.id: r};
          _isLoading = false;
        });
      } else {
        final rides = await _supabaseService.getRidesByDriverId(_driver.id);
        final rideRequestIds = rides
            .map((r) => r.rideRequestId?.trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final rideRequests =
            await _supabaseService.getRideRequestsByIds(rideRequestIds);
        final rideReqMap = {for (final rr in rideRequests) rr.id: rr};
        final riderIds = rides
            .map((r) => r.riderId?.trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final riders = await _supabaseService.getUsersByIds(riderIds);
        final ridersMap = {for (final u in riders) u.id: u};
        setState(() {
          _foodOrders = [];
          _restaurantsMap = {};
          _rides = rides;
          _rideRequestsById = rideReqMap;
          _ridersById = ridersMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _activateDriver() async {
    setState(() => _activating = true);
    try {
      await _supabaseService.updateDriverStatus(_driver.id, true);
      final notify = await AccountDecisionNotifier.driverApproved(_driver);
      final updated = await _supabaseService.getDriverById(_driver.id);
      if (updated != null && mounted) {
        setState(() {
          _driverState = updated;
          _activating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver activated — ${notify.message}'),
            backgroundColor: notify.ok ? Colors.green : Colors.orange,
          ),
        );
      } else {
        setState(() => _activating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _activating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          _driver.name ?? 'Driver Details',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          if (_driverPushToken != null)
            IconButton(
              onPressed: _sendingNoti ? null : _showSendNotificationDialog,
              icon: _sendingNoti
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined,
                      color: Colors.blueAccent),
              tooltip: 'Send notification',
            ),
          if (!_driver.activated)
            TextButton.icon(
              onPressed: _activating ? null : _activateDriver,
              icon: _activating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              label: Text(
                _activating ? 'Activating...' : 'Activate',
                style: const TextStyle(color: Colors.greenAccent),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.deepPurpleAccent,
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(text: 'Profile'),
            Tab(text: _isFoodDriver ? 'Analysis' : 'Analysis'),
            Tab(text: _isFoodDriver ? 'Food Orders' : 'Rides'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _isFoodDriver ? _buildFoodAnalysisTab() : _buildRidesAnalysisTab(),
                    _isFoodDriver ? _buildFoodOrdersTab() : _buildRidesTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('$_error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final d = _driver;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!d.activated) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Driver not activated. Review documents below and activate when ready.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _activating ? null : _activateDriver,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black87,
                    ),
                    icon: _activating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                          )
                        : const Icon(Icons.check_circle, size: 20),
                    label: Text(_activating ? 'Activating...' : 'Activate driver'),
                  ),
                ],
              ),
            ),
          ],
          _sectionTitle('Basic'),
          _infoCard([
            _row('Name', d.name),
            _row('Email', d.email),
            _row('Phone', d.phone),
            _row('City', d.city),
            _row('Type', d.type ?? 'ride'),
            _row('Rate', d.rate.toStringAsFixed(1)),
            _row('Activated', d.activated ? 'Yes' : 'No'),
            _row('Online', d.online ? 'Yes' : 'No'),
            _row('Created', d.formattedDate),
          ]),
          if (d.carInfo != null && d.carInfo!.isNotEmpty) ...[
            _sectionTitle('Car info'),
            _infoCard([
              _row('make', d.carInfo!['make']?.toString() ?? d.carInfo!['brand']?.toString()),
              _row('model', d.carInfo!['model']?.toString()),
              _row('year', d.carInfo!['year']?.toString()),
              _row('color', d.carInfo!['color']?.toString()),
              _row('plate_number', d.carInfo!['plate_number']?.toString()),
              _row('vehicle_type', d.carInfo!['vehicle_type']?.toString()),
            ]),
            if (d.carInfo!['insurance_doc'] != null)
              _mediaTile('insurance_doc', d.carInfo!['insurance_doc'].toString(), false),
            if (d.carInfo!['registration_doc'] != null)
              _mediaTile('registration_doc', d.carInfo!['registration_doc'].toString(), false),
            if (d.carImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => _showFullscreenImage(d.carImage!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 280,
                      height: 140,
                      child: FirebaseStorageImage(
                        imageUrl: d.carImage!,
                        width: 280,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          _sectionTitle('Documents & media (tap to view)'),
          if (d.licenseFrontSide != null)
            _mediaTile('License (front)', d.licenseFrontSide!, false),
          if (d.licenseBackSide != null)
            _mediaTile('License (back)', d.licenseBackSide!, false),
          if (d.idFrontSide != null)
            _mediaTile('ID (front)', d.idFrontSide!, false),
          if (d.idBackSide != null)
            _mediaTile('ID (back)', d.idBackSide!, false),
          if (d.backgroundCheck != null)
            _mediaTile('Background check', d.backgroundCheck!, false),
          if (d.video != null && d.video!.isNotEmpty)
            _mediaTile('Video', d.video!, true),
          if (d.licenseFrontSide == null &&
              d.licenseBackSide == null &&
              d.idFrontSide == null &&
              d.idBackSide == null &&
              d.backgroundCheck == null &&
              (d.video == null || d.video!.isEmpty))
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No documents or media uploaded.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          if (_driverPushToken != null) ...[
            _sectionTitle('Notification'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendingNoti ? null : _showSendNotificationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _sendingNoti
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text(_sendingNoti ? 'Sending...' : 'Send notification'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSendNotificationDialog() async {
    final token = _driverPushToken;
    if (token == null) return;

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text('Send notification to ${_driver.name ?? 'driver'}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bodyController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: 'Enter notification message',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Message is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'body': bodyController.text.trim(),
              });
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      bodyController.dispose();
    });

    if (result == null || !mounted) return;

    setState(() => _sendingNoti = true);
    final sent = await AdminNotificationSender.send(
      recipientType: 'driver',
      recipientId: _driver.id,
      deviceToken: token,
      title: result['title']!,
      body: result['body']!,
    );
    if (!mounted) return;
    setState(() => _sendingNoti = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent.message),
        backgroundColor: sent.ok ? Colors.green : Colors.red,
      ),
    );
  }

  void _showFullscreenImage(String url) {
    final resolved = FirebaseStorageImage.normalizeUrl(url) ?? url;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  resolved,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTile(String title, String url, bool isVideo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isVideo)
            _VideoPlayerView(
              url: url,
              onMaximize: () => _showFullscreenVideo(url),
            )
          else
            GestureDetector(
              onTap: () => _showFullscreenImage(url),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FirebaseStorageImage(
                    imageUrl: url,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.broken_image,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullscreenVideo(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Stack(
          children: [
            Center(
              child: _VideoPlayerView(
                url: url,
                fullscreen: true,
                onMaximize: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent,
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value ?? '—',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesAnalysisTab() {
    final completed = _rides.where((r) => r.isCompleted).toList();
    final totalEarned =
        completed.fold<double>(0, (sum, r) => sum + r.driverFare);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary for ${_driver.name ?? "Driver"}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _analysisCard(
            'Rides',
            [
              _statRow('Total rides', '${_rides.length}'),
              _statRow('Completed', '${completed.length}'),
              _statRow('Total fares', formatMoney(totalEarned)),
            ],
            Icons.directions_car,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _analysisCard(
            'Rating',
            [
              _statRow('Driver rating', _driver.rate.toStringAsFixed(1)),
              _statRow(
                  'Status', _driver.activated ? 'Activated' : 'Pending'),
            ],
            Icons.star,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodAnalysisTab() {
    final done = _foodOrders.where((o) => o.isCompleted).toList();
    // The food driver earns the delivery fee of each delivered order.
    final totalEarned =
        done.fold<double>(0, (sum, o) => sum + (o.deliveryPrice ?? 0));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary for ${_driver.name ?? "Driver"}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _analysisCard(
            'Food Orders',
            [
              _statRow('Total deliveries', '${_foodOrders.length}'),
              _statRow('Delivered', '${done.length}'),
              _statRow('Earned (delivery fees)', formatMoney(totalEarned)),
            ],
            Icons.restaurant,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _analysisCard(
            'Rating',
            [
              _statRow('Driver rating', _driver.rate.toStringAsFixed(1)),
              _statRow(
                  'Status', _driver.activated ? 'Activated' : 'Pending'),
            ],
            Icons.star,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _analysisCard(
      String title, List<Widget> rows, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRidesTab() {
    if (_rides.isEmpty) {
      return const Center(
          child: Text('No rides yet.', style: TextStyle(color: Colors.grey)));
    }
    final sorted = [..._rides]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final ride = sorted[i];
        final rideRequest = ride.rideRequestId != null
            ? _rideRequestsById[ride.rideRequestId!.trim()]
            : null;
        final rider =
            ride.riderId != null ? _ridersById[ride.riderId!.trim()] : null;
        final statusColor = _getRideStatusColor(ride.status);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_car, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatRideCurrency(ride.totalPrice),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ride.formattedCreatedAt,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildRideStatusPill(ride.status, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              _buildRideKeyValueGrid([
                _rideKv('id', ride.id),
                _rideKv('pickup_place', rideRequest?.pickupPlace ?? ''),
                _rideKv('dropoff_place', rideRequest?.dropoffPlace ?? ''),
                _rideKv('start_time', _formatRideDateTime(ride.startTime)),
                _rideKv('end_time', _formatRideDateTime(ride.endTime)),
                _rideKv(
                  'duration',
                  ride.startTime != null && ride.endTime != null
                      ? ride.duration
                      : '',
                ),
                _rideKv('total_price (driver fare)', _formatRideCurrency(ride.driverFare)),
                _rideKv('rider paid', _formatRideCurrency(ride.riderPaid)),
                _rideKv(
                  'coupon (paid by app)',
                  ride.hasCouponDiscount
                      ? _formatRideCurrency(ride.couponCovered)
                      : '',
                ),
                _rideKv('created_at', _formatRideDateTime(ride.createdAt)),
                _rideKv('status', ride.status ?? ''),
              ]),
              const SizedBox(height: 10),
              _buildRideRiderSection(ride, rider),
              const SizedBox(height: 10),
              _buildDriverRidePaymentCard(ride),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRideRiderSection(RideModel ride, UserModel? rider) {
    if (rider != null) {
      final hasAny = _rideNotBlank(rider.name) ||
          _rideNotBlank(rider.email) ||
          _rideNotBlank(rider.phone) ||
          _rideNotBlank(rider.userType) ||
          _rideNotBlank(rider.profile);
      if (!hasAny) {
        return _buildDriverInfoSectionCard(
          title: 'Rider (user)',
          icon: Icons.person_outline,
          color: Colors.deepPurpleAccent,
          child: _buildRideKeyValueGrid([
            _rideKv('id', rider.id),
          ]),
        );
      }
      return _buildDriverInfoSectionCard(
        title: 'Rider (user)',
        icon: Icons.person_outline,
        color: Colors.deepPurpleAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_rideNotBlank(rider.profile))
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: FirebaseStorageImage(
                      imageUrl: rider.profile!.trim(),
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                      fallbackIconColor: Colors.white70,
                    ),
                  ),
                ),
              ),
            if (_rideNotBlank(rider.profile)) const SizedBox(height: 10),
            _buildRideKeyValueGrid([
              _rideKv('id', rider.id),
              _rideKv('name', rider.name ?? ''),
              _rideKv('email', rider.email ?? ''),
              _rideKv('phone', rider.phone ?? ''),
              _rideKv('user_type', rider.userType ?? ''),
              _rideKv('created_at', rider.formattedDate),
            ]),
          ],
        ),
      );
    }
    if (_rideNotBlank(ride.riderId)) {
      return _buildDriverInfoSectionCard(
        title: 'Rider (user)',
        icon: Icons.person_outline,
        color: Colors.deepPurpleAccent,
        child: _buildRideKeyValueGrid([
          _rideKv('rider_id', ride.riderId!.trim()),
          _rideKv(
            'note',
            'User row not found in users table for this rider_id.',
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDriverRidePaymentCard(RideModel ride) {
    final cashStr = ride.totalCash != null && ride.totalCash! > 0
        ? _formatRideCurrency(ride.totalCash)
        : '';
    final walletStr = ride.totalWallet != null && ride.totalWallet! > 0
        ? _formatRideCurrency(ride.totalWallet)
        : '';
    return _buildDriverInfoSectionCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      color: Colors.greenAccent,
      child: _buildRideKeyValueGrid([
        _rideKv('payment_type', ride.paymentType ?? ''),
        _rideKv('total_cash', cashStr),
        _rideKv('total_wallet', walletStr),
        _rideKv('payment_sent', ride.paymentSent ? 'true' : 'false'),
      ]),
    );
  }

  Widget _buildDriverInfoSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildRideStatusPill(String? status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        (status ?? 'N/A').replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildRideKeyValueGrid(List<MapEntry<String, String>> entries) {
    final visible =
        entries.where((e) => _rideNotBlank(e.value)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      children: visible
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      entry.key,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  MapEntry<String, String> _rideKv(String key, String value) =>
      MapEntry(key, value);

  String _formatRideCurrency(num? value) => formatMoney(value);

  String _formatRideDateTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('MMM dd, yyyy • HH:mm').format(value);
  }

  bool _rideNotBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  Widget _buildFoodOrdersTab() {
    if (_foodOrders.isEmpty) {
      return const Center(
        child: Text('No food orders yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _foodOrders.length,
      itemBuilder: (context, i) {
        final order = _foodOrders[i];
        final restaurant = order.restaurantId != null
            ? _restaurantsMap[order.restaurantId!]
            : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.restaurant,
                color: _getOrderStatusColor(order.status),
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.formattedCreatedAt,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant?.name ?? 'Restaurant #${order.restaurantId}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${formatMoney(order.grandTotal)} • delivery ${formatMoney(order.deliveryPrice)} • ${order.status ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRideStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.greenAccent;
      case 'in_trip':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'done':
      case 'delivered':
        return Colors.greenAccent;
      case 'accepted':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }
}

class _VideoPlayerView extends StatefulWidget {
  final String url;
  final bool fullscreen;
  final VoidCallback? onMaximize;

  const _VideoPlayerView({
    required this.url,
    this.fullscreen = false,
    this.onMaximize,
  });

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final resolved =
        FirebaseStorageImage.normalizeUrl(widget.url) ?? widget.url;
    _controller = VideoPlayerController.networkUrl(Uri.parse(resolved))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        if (widget.fullscreen) {
          _controller.play();
        }
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _maxHeightWeb = 220;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Icon(Icons.videocam_off, color: Colors.grey, size: 48),
        ),
      );
    }

    final content = _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio == 0
                ? 16 / 9
                : _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                GestureDetector(
                  onTap: () => setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  }),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white70,
                        size: widget.fullscreen ? 80 : 64,
                      ),
                    ),
                  ),
                ),
                if (widget.onMaximize != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: widget.fullscreen ? 'Minimize' : 'Maximize',
                        icon: Icon(
                          widget.fullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: widget.onMaximize,
                      ),
                    ),
                  ),
              ],
            ),
          )
        : SizedBox(
            height: widget.fullscreen ? 280 : 200,
            child: const Center(child: CircularProgressIndicator()),
          );

    if (widget.fullscreen) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.92,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: kIsWeb
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: _maxHeightWeb,
                  maxWidth: 400,
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
