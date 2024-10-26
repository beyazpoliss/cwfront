import 'package:flutter/material.dart';
import 'app_localizations.dart'; // Import AppLocalizations for localization

class UnsuccessfulReportPage extends StatelessWidget {
  const UnsuccessfulReportPage({Key? key, required bool isClockIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context); // Get localization instance

    return Scaffold(
      backgroundColor: Colors.black, // Set background color to black
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error message
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.red, // Red background for error
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                localizations!.translate('report_unsuccessful'), // Localized error message
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20), // Space between messages
            Text(
              localizations.translate('please_upload_image'), // Localized prompt
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
