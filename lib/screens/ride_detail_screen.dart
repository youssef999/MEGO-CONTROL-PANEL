import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';

class RideDetailScreen extends StatefulWidget {
  final RideModel ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final SupabaseService _supabase = SupabaseService();

  RideRequestModel? _request;
  DriverModel? _driver;
  UserModel? _rider;
  bool _loading = true;
  String? _error;

  RideModel get _r => widget.ride;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      RideRequestModel? req;
      if (_r.rideRequestId != null && _r.rideRequestId!.trim().isNotEmpty) {
        final list =
            await _supabase.getRideRequestsByIds([_r.rideRequestId!.trim()]);
        if (list.isNotEmpty) req = list.first;
      }
      DriverModel? driver;
      if (_r.driverId != null && _r.driverId!.trim().isNotEmpty) {
        driver = await _supabase.getDriverById(_r.driverId!.trim());
      }
      UserModel? rider;
      if (_r.riderId != null && _r.riderId!.trim().isNotEmpty) {
        final users = await _supabase.getUsersByIds([_r.riderId!.trim()]);
        if (users.isNotEmpty) rider = users.first;
      }
      if (!mounted) return;
      setState(() {
        _request = req;
        _driver = driver;
        _rider = rider;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_r.status);
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Ride • ${_r.formattedCreatedAt}',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(statusColor),
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Route',
                        icon: Icons.route,
                        color: Colors.orangeAccent,
                        child: _kvGrid([
                          _e('pickup_place', _request?.pickupPlace ?? ''),
                          _e('dropoff_place', _request?.dropoffPlace ?? ''),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _buildSection(
                        title: 'Ride',
                        icon: Icons.directions_car,
                        color: Colors.blueAccent,
                        child: _kvGrid([
                          _e('id', _r.id),
                          _e('ride_request_id', _r.rideRequestId ?? ''),
                          _e('start_time', _dt(_r.startTime)),
                          _e('end_time', _dt(_r.endTime)),
                          _e(
                            'duration',
                            _r.startTime != null && _r.endTime != null
                                ? _r.duration
                                : '',
                          ),
                          _e('total_price (driver fare)', _gbp(_r.driverFare)),
                          _e('rider paid', _gbp(_r.riderPaid)),
                          _e(
                            'coupon (paid by app)',
                            _r.hasCouponDiscount ? _gbp(_r.couponCovered) : '',
                          ),
                          _e('created_at', _dt(_r.createdAt)),
                          _e('status', _r.status ?? ''),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _buildSection(
                        title: 'Payment',
                        icon: Icons.payments_outlined,
                        color: Colors.greenAccent,
                        child: _kvGrid([
                          _e('payment_type', _r.paymentType ?? ''),
                          _e('rider paid', _gbp(_r.riderPaid)),
                          _e('payment_sent', _r.paymentSent ? 'true' : 'false'),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _buildDriverBlock(),
                      const SizedBox(height: 14),
                      _buildRiderBlock(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_taxi, color: statusColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _r.hasCouponDiscount
                      ? '${_gbp(_r.driverFare)}  •  rider paid ${_gbp(_r.riderPaid)}'
                      : _gbp(_r.driverFare),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _r.formattedCreatedAt,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
          _statusPill(_r.status, statusColor),
        ],
      ),
    );
  }

  Widget _buildDriverBlock() {
    final d = _driver;
    if (d != null) {
      return _buildSection(
        title: 'Driver',
        icon: Icons.badge,
        color: Colors.lightBlueAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_nonEmpty(d.profileImage))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseStorageImage(
                    imageUrl: d.profileImage!.trim(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                    fallbackIconColor: Colors.white38,
                  ),
                ),
              ),
            _kvGrid([
              _e('id', d.id),
              _e('name', d.name ?? ''),
              _e('email', d.email ?? ''),
              _e('phone', d.phone ?? ''),
              _e('rate', d.rate.toStringAsFixed(1)),
            ]),
          ],
        ),
      );
    }
    if (_nonEmpty(_r.driverId)) {
      return _buildSection(
        title: 'Driver',
        icon: Icons.badge,
        color: Colors.lightBlueAccent,
        child: _kvGrid([
          _e('driver_id', _r.driverId!.trim()),
          _e('note', 'No driver row found for this id.'),
        ]),
      );
    }
    return _buildSection(
      title: 'Driver',
      icon: Icons.badge,
      color: Colors.lightBlueAccent,
      child: Text(
        'No driver assigned.',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  Widget _buildRiderBlock() {
    final u = _rider;
    if (u != null) {
      return _buildSection(
        title: 'Rider (user)',
        icon: Icons.person_outline,
        color: Colors.deepPurpleAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_nonEmpty(u.profile))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseStorageImage(
                    imageUrl: u.profile!.trim(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                    fallbackIconColor: Colors.white38,
                  ),
                ),
              ),
            _kvGrid([
              _e('id', u.id),
              _e('name', u.name ?? ''),
              _e('email', u.email ?? ''),
              _e('phone', u.phone ?? ''),
              _e('user_type', u.userType ?? ''),
              _e('created_at', u.formattedDate),
            ]),
          ],
        ),
      );
    }
    if (_nonEmpty(_r.riderId)) {
      return _buildSection(
        title: 'Rider (user)',
        icon: Icons.person_outline,
        color: Colors.deepPurpleAccent,
        child: _kvGrid([
          _e('rider_id', _r.riderId!.trim()),
          _e('note', 'No user row found for this rider_id.'),
        ]),
      );
    }
    return _buildSection(
      title: 'Rider (user)',
      icon: Icons.person_outline,
      color: Colors.deepPurpleAccent,
      child: Text(
        'No rider on this ride.',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kvGrid(List<MapEntry<String, String>> entries) {
    final rows = entries.where((e) => _nonEmpty(e.value)).toList();
    if (rows.isEmpty) {
      return Text(
        '—',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    return Column(
      children: rows
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      e.key,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  MapEntry<String, String> _e(String k, String v) => MapEntry(k, v);

  String _dt(DateTime? t) =>
      t == null ? '' : DateFormat('MMM dd, yyyy • HH:mm').format(t);

  String _gbp(num? n) => formatMoney(n);

  bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

  Widget _statusPill(String? status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        (status ?? 'N/A').replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.greenAccent;
      case 'in_trip':
        return Colors.blueAccent;
      case 'in_progress':
        return Colors.orangeAccent;
      case 'arrived':
        return Colors.yellowAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
