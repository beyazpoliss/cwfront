import 'package:flutter/material.dart';
import 'app_localizations.dart'; // Import AppLocalizations for localization

class ReportSuccessPage extends StatelessWidget {
  const ReportSuccessPage({Key? key, required bool isClockIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context); // Get localization instance

    return Scaffold(
      backgroundColor: Colors.black, // Set background color to black
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success message
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.green, // Green background for success
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                localizations!.translate('report_successful'), // Localized success message
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20), // Space between messages
            Text(
              localizations.translate('thank_you_message'), // Localized thank you message
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40), // Space before button
            // Back button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Go back to previous page
              },
              child: const Text(
                'Click to Go-Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}