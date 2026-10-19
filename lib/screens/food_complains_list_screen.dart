import 'package:flutter/material.dart';
import '../models/food_complain_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'food_complain_detail_screen.dart';

enum _ComplainFilter { all, unsolved, solved }

class FoodComplainsListScreen extends StatefulWidget {
  const FoodComplainsListScreen({super.key});

  @override
  State<FoodComplainsListScreen> createState() =>
      _FoodComplainsListScreenState();
}

class _FoodComplainsListScreenState extends State<FoodComplainsListScreen> {
  final _supabase = SupabaseService();
  final _searchController = TextEditingController();

  List<FoodComplainModel> _all = [];
  List<FoodComplainModel> _filtered = [];
  Map<String, UserModel> _users = {};
  bool _loading = true;
  String? _error;
  _ComplainFilter _filter = _ComplainFilter.unsolved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _supabase.getFoodComplains();
      final userIds = list
          .map((c) => c.userId?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final users = await _supabase.getUsersByIds(userIds);
      if (!mounted) return;
      setState(() {
        _all = list;
        _users = {for (final u in users) u.id: u};
        _applyFilter();
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

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((c) {
      final matchesFilter = switch (_filter) {
        _ComplainFilter.all => true,
        _ComplainFilter.unsolved => !c.isSolve,
        _ComplainFilter.solved => c.isSolve,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final user = c.userId != null ? _users[c.userId] : null;
      return c.id.toString().contains(query) ||
          (c.type?.toLowerCase().contains(query) ?? false) ||
          (c.message?.toLowerCase().contains(query) ?? false) ||
          (c.userId?.toLowerCase().contains(query) ?? false) ||
          (user?.name?.toLowerCase().contains(query) ?? false) ||
          (user?.email?.toLowerCase().contains(query) ?? false) ||
          (c.orderId?.toString().contains(query) ?? false);
    }).toList();
  }

  int get _unsolvedCount => _all.where((c) => !c.isSolve).length;
  int get _solvedCount => _all.where((c) => c.isSolve).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Food Complaints'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Food Complaints',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStats(),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 16),
            _buildSearch(),
            const SizedBox(height: 20),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _statCard(
          label: 'Total',
          value: '${_all.length}',
          color: Colors.deepPurpleAccent,
          icon: Icons.report_outlined,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Unsolved',
          value: '$_unsolvedCount',
          color: Colors.orangeAccent,
          icon: Icons.pending_actions_outlined,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Solved',
          value: '$_solvedCount',
          color: Colors.greenAccent,
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _filterTab('All', _ComplainFilter.all, _all.length),
          _filterTab('Unsolved', _ComplainFilter.unsolved, _unsolvedCount),
          _filterTab('Solved', _ComplainFilter.solved, _solvedCount),
        ],
      ),
    );
  }

  Widget _filterTab(String label, _ComplainFilter value, int count) {
    final selected = _filter == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _filter = value;
            _applyFilter();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.deepPurple.withOpacity(0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.deepPurpleAccent.withOpacity(0.4)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(_applyFilter),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by message, user, type, order id...',
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(_applyFilter);
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1A1D2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'No complaints found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = _filtered[index];
        final user = c.userId != null ? _users[c.userId] : null;
        return _buildCard(c, user);
      },
    );
  }

  Widget _buildCard(FoodComplainModel c, UserModel? user) {
    final solved = c.isSolve;
    return Material(
      color: const Color(0xFF1A1D2D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FoodComplainDetailScreen(complain: c),
            ),
          );
          if (mounted) _load();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: solved
                  ? Colors.green.withOpacity(0.25)
                  : Colors.orange.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (solved ? Colors.green : Colors.orange)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  solved ? Icons.check_circle_outline : Icons.report_outlined,
                  color: solved ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${c.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          (c.type ?? 'general').toUpperCase(),
                          Colors.deepPurpleAccent,
                        ),
                        if (c.isOrderType && c.orderId != null) ...[
                          const SizedBox(width: 6),
                          _chip('Order #${c.orderId}', Colors.tealAccent),
                        ],
                        const Spacer(),
                        _chip(
                          solved ? 'Solved' : 'Unsolved',
                          solved ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.message?.trim().isNotEmpty == true
                          ? c.message!.trim()
                          : 'No message',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[300], height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            user?.name ??
                                user?.email ??
                                c.userId ??
                                'Unknown user',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          c.formattedCreatedAt,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
