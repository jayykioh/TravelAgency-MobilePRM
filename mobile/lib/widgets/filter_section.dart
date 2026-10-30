import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

class HotelFilterSheet extends StatefulWidget {
  const HotelFilterSheet({super.key});
  @override
  State<HotelFilterSheet> createState() => HotelFilterSheetState();
}

class HotelFilterSheetState extends State<HotelFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    const amenityOptions = <String, String>{
      'breakfast': 'Free Breakfast',
      'pool': 'Swimming Pool',
      'spa': 'Spa & Wellness',
      'wifi': 'Free WiFi',
      'beach': 'Beach Access',
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    state.priceRange = const RangeValues(50, 1000);
                    state.stars.clear();
                    state.amenities.clear();
                    state.propertyTypes.clear();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const Text('Price Range'),
            RangeSlider(
              min: 50,
              max: 1000,
              divisions: 19,
              labels: RangeLabels(
                '\$${state.priceRange.start.round()}',
                '\$${state.priceRange.end.round()}',
              ),
              values: state.priceRange,
              onChanged: (value) => setState(() => state.priceRange = value),
            ),
            const Text('Star Rating'),
            for (final star in [5, 4, 3])
              CheckboxListTile(
                value: state.stars.contains(star),
                title: Text('${List.filled(star, '★').join()}  $star Stars'),
                onChanged: (_) => setState(() {
                  state.stars.contains(star)
                      ? state.stars.remove(star)
                      : state.stars.add(star);
                }),
              ),
            const Text('Amenities'),
            for (final entry in amenityOptions.entries)
              CheckboxListTile(
                value: state.amenities.contains(entry.key),
                title: Text(entry.value),
                onChanged: (_) => setState(() {
                  state.amenities.contains(entry.key)
                      ? state.amenities.remove(entry.key)
                      : state.amenities.add(entry.key);
                }),
              ),
            const Text('Property type'),
            for (final type in ['hotel', 'resort', 'villa', 'apartment'])
              CheckboxListTile(
                value: state.propertyTypes.contains(type),
                title: Text(type[0].toUpperCase() + type.substring(1)),
                onChanged: (_) => setState(() {
                  state.propertyTypes.contains(type)
                      ? state.propertyTypes.remove(type)
                      : state.propertyTypes.add(type);
                }),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
