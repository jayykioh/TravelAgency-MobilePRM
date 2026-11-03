import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

class HotelFilterSheet extends StatefulWidget {
  const HotelFilterSheet({super.key});
  @override
  State<HotelFilterSheet> createState() => HotelFilterSheetState();
}

class HotelFilterSheetState extends State<HotelFilterSheet> {
  static const amenityOptions = <String, (String, IconData)>{
    'breakfast': ('Free Breakfast', Icons.free_breakfast_rounded),
    'pool': ('Swimming Pool', Icons.pool_rounded),
    'spa': ('Spa & Wellness', Icons.spa_rounded),
    'wifi': ('Free WiFi', Icons.wifi_rounded),
    'beach': ('Beach Access', Icons.beach_access_rounded),
    'fitness': ('Fitness Center', Icons.fitness_center_rounded),
    'parking': ('Free Parking', Icons.local_parking_rounded),
  };

  static const propertyTypeOptions = <String, (String, IconData)>{
    'hotel': ('Khách sạn', Icons.hotel_rounded),
    'resort': ('Resort', Icons.holiday_village_rounded),
    'villa': ('Villa', Icons.villa_rounded),
    'apartment': ('Căn hộ', Icons.apartment_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    final count = state.activeFiltersCount;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // Title and Reset header
              Row(
                children: [
                  const Text(
                    'Bộ lọc tìm kiếm',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5E1F),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: count > 0
                          ? const Color(0xFFFF5E1F)
                          : const Color(0xFF94A3B8),
                    ),
                    onPressed: count > 0
                        ? () {
                            state.clearFilters();
                          }
                        : null,
                    child: const Text('Thiết lập lại'),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),

              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Price Range Section
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Khoảng giá (mỗi đêm)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD5C2)),
                          ),
                          child: Text(
                            '\$${state.priceRange.start.round()} – \$${state.priceRange.end.round()}${state.priceRange.end >= 1000 ? '+' : ''}',
                            style: const TextStyle(
                              color: Color(0xFFFF5E1F),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RangeSlider(
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      activeColor: const Color(0xFFFF5E1F),
                      inactiveColor: const Color(0xFFE2E8F0),
                      labels: RangeLabels(
                        '\$${state.priceRange.start.round()}',
                        '\$${state.priceRange.end.round()}',
                      ),
                      values: state.priceRange,
                      onChanged: (value) => setState(() => state.priceRange = value),
                    ),
                    const SizedBox(height: 16),

                    // Star Rating Section
                    const Text(
                      'Hạng sao khách sạn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [5, 4, 3, 2].map((star) {
                        final selected = state.stars.contains(star);
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$star'),
                              const SizedBox(width: 3),
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                            ],
                          ),
                          selected: selected,
                          selectedColor: const Color(0xFFFFF7ED),
                          checkmarkColor: const Color(0xFFFF5E1F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected ? const Color(0xFFFF5E1F) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              val ? state.stars.add(star) : state.stars.remove(star);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Amenities Section
                    const Text(
                      'Tiện ích mong muốn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: amenityOptions.entries.map((entry) {
                        final selected = state.amenities.contains(entry.key);
                        return FilterChip(
                          avatar: Icon(
                            entry.value.$2,
                            size: 16,
                            color: selected ? const Color(0xFFFF5E1F) : const Color(0xFF64748B),
                          ),
                          label: Text(entry.value.$1),
                          selected: selected,
                          selectedColor: const Color(0xFFFFF7ED),
                          checkmarkColor: const Color(0xFFFF5E1F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected ? const Color(0xFFFF5E1F) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              val ? state.amenities.add(entry.key) : state.amenities.remove(entry.key);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Property Types Section
                    const Text(
                      'Loại hình lưu trú',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: propertyTypeOptions.entries.map((entry) {
                        final selected = state.propertyTypes.contains(entry.key);
                        return FilterChip(
                          avatar: Icon(
                            entry.value.$2,
                            size: 16,
                            color: selected ? const Color(0xFFFF5E1F) : const Color(0xFF64748B),
                          ),
                          label: Text(entry.value.$1),
                          selected: selected,
                          selectedColor: const Color(0xFFFFF7ED),
                          checkmarkColor: const Color(0xFFFF5E1F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected ? const Color(0xFFFF5E1F) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              val
                                  ? state.propertyTypes.add(entry.key)
                                  : state.propertyTypes.remove(entry.key);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Bottom Apply Button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5E1F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    count > 0 ? 'Áp dụng $count bộ lọc' : 'Xem kết quả',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
