import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/loginRegister/indonesia_state_area.dart';
import 'package:luckygo_pemandu/loginRegister/timor_leste_state_area.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'malaysia_state_area.dart';

// Expect these in your other files:
// const Map<String, List<String>> indonesiaStateAreas = {...};
// const Map<String, List<String>> timorLesteStateAreas = {...};

class FillFormPopup extends StatefulWidget {
  const FillFormPopup({super.key});

  @override
  State<FillFormPopup> createState() => _FillFormPopupState();
}

class _FillFormPopupState extends State<FillFormPopup> {
  String? selectedCountry;
  String? selectedState;
  String? selectedArea;
  String? selectedLanguage;

  // One source of truth: Country -> (State -> Areas)
  late final Map<String, Map<String, List<String>>> countryStateAreas = {
    'Malaysia': malaysiaStateAreas,
    'Indonesia': indonesiaStateAreas,
    'Timor-Leste': timorLesteStateAreas,
  };

  // Default country-level fallback
  final Map<String, List<String>> countryLanguages = const {
    'Malaysia': ['Malay', 'English', 'Chinese'],
    'Indonesia': ['Indonesian', 'English', 'Balinese', 'Chinese'],
    'Timor-Leste': ['Tetun', 'Portuguese', 'Indonesian', 'English', 'Fataluku'],
  };

  // Optional state-specific overrides
  final Map<String, List<String>> malaysiaStateLanguages = const {
    'Sabah': ['Malay', 'English', 'Chinese', 'Dusun'],
    // Add more state-specific overrides if needed
  };

  List<String> _statesFor(String? country) {
    if (country == null) return const [];
    return countryStateAreas[country]?.keys.toList() ?? const [];
  }

  List<String> _areasFor(String? country, String? state) {
    if (country == null || state == null) return const [];
    return countryStateAreas[country]?[state] ?? const [];
  }

  List<String> _languagesFor(String? country, String? state) {
    if (country == null) return const [];

    // Special case: Malaysia + Sabah
    if (country == 'Malaysia' && state == 'Sabah') {
      return malaysiaStateLanguages['Sabah'] ?? countryLanguages[country] ?? const [];
    }

    // Default fallback
    return countryLanguages[country] ?? const [];
  }

  void _onCountryChanged(String? country) {
    setState(() {
      selectedCountry = country;
      selectedState = null;
      selectedArea = null;
      selectedLanguage = null;
    });
  }

  void _onStateChanged(String? state) {
    setState(() {
      selectedState = state;
      selectedArea = null;
      selectedLanguage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final states = _statesFor(selectedCountry);
    final areas = _areasFor(selectedCountry, selectedState);
    final langs = _languagesFor(selectedCountry, selectedState);

    return AlertDialog(
      title: const Text('Fill Form'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Country
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedCountry,
              decoration: const InputDecoration(labelText: 'Country'),
              items: countryStateAreas.keys
                  .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                  .toList(),
              onChanged: _onCountryChanged,
            ),
            const SizedBox(height: 10),

            // State
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedState,
              decoration: const InputDecoration(labelText: 'State'),
              items: states
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: states.isEmpty ? null : _onStateChanged,
            ),
            const SizedBox(height: 10),

            // Area
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedArea,
              decoration: const InputDecoration(labelText: 'Area'),
              items: areas
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (areas.isEmpty) ? null : (v) => setState(() => selectedArea = v),
            ),
            const SizedBox(height: 10),

            // Language
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedLanguage,
              decoration: const InputDecoration(labelText: 'Language'),
              items: langs
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (langs.isEmpty) ? null : (v) => setState(() => selectedLanguage = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
ElevatedButton(
  onPressed: () async {
    if (selectedCountry == null ||
        selectedState == null ||
        selectedArea == null ||
        selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all fields')),
      );
      return;
    }

    // Save to SharedPreferences so LoginPage can fetch it later
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country',  selectedCountry!);
    await prefs.setString('state',    selectedState!);
    await prefs.setString('area',     selectedArea!);
    await prefs.setString('language', selectedLanguage!);

    // Close the popup and return the selected values
    Navigator.pop(context, {
      'country':  selectedCountry,
      'state':    selectedState,
      'area':     selectedArea,
      'language': selectedLanguage,
    });
  },
  child: const Text('Save'),
)

      ],
    );
  }
}
