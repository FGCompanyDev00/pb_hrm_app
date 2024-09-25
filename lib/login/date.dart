import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

class DateProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();

  // Getter for selectedDate
  DateTime get selectedDate => _selectedDate;

 
  String get formattedSelectedDate => DateFormat('dd MMM yyyy').format(_selectedDate);

  // Method to update the selectedDate
  void updateSelectedDate(DateTime newDate) {
    _selectedDate = newDate;
    notifyListeners();  
  }
}
