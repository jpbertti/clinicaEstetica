import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Color primaryColor;
  final Color accentColor;

  const CustomDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _focusedMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _focusedMonth = _startDate ?? DateTime.now();
    // Garantir que estamos no primeiro dia do mês para exibição correta
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else if (date.isBefore(_startDate!)) {
        _startDate = date;
        _endDate = null;
      } else {
        _endDate = date;
      }
    });
  }

  bool _isRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  bool _isSelected(DateTime date) {
    if (_startDate != null && _isSameDay(date, _startDate!)) return true;
    if (_endDate != null && _isSameDay(date, _endDate!)) return true;
    return false;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOffset = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Ajuste para Domingo = 0
    
    // Nomes dos meses em PT-BR
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedMonth);
    final capitalizedMonth = monthLabel.substring(0, 1).toUpperCase() + monthLabel.substring(1);

    final weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Selecionar Período',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_startDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _endDate == null 
                  ? 'De: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'
                  : 'Período: ${DateFormat('dd/MM').format(_startDate!)} até ${DateFormat('dd/MM').format(_endDate!)}',
                style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor,
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Mês e Setas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                capitalizedMonth,
                style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((d) => SizedBox(
              width: 35,
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            )).toList(),
          ),
          
          const SizedBox(height: 8),
          
          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + firstDayOffset,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox();
              
              final day = index - firstDayOffset + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isSelected = _isSelected(date);
              final isInRange = _isRange(date);
              
              return GestureDetector(
                onTap: () => _onDateSelected(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? widget.accentColor 
                        : (isInRange ? widget.accentColor.withOpacity(0.2) : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? Colors.white 
                            : (date.isAfter(DateTime.now()) ? Colors.grey[300] : widget.primaryColor),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Botão Filtrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startDate != null ? () {
                Navigator.pop(context, DateTimeRange(
                  start: _startDate!,
                  end: _endDate ?? _startDate!,
                ));
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'Filtrar',
                style: TextStyle(fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

