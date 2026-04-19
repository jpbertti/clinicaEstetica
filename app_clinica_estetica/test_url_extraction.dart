
void main() {
  final iframe = '<iframe src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d6167.645154916926!2d-45.88971545621486!3d-23.195598408446266!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x94cc4bc573d3cedb%3A0x1a06d2ea7c223489!2sEmporium%20da%20Arte!5e0!3m2!1spt-BR!2sbr!4v1774125143693!5m2!1spt-BR!2sbr" width="100%" height="250" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>';
  
  String? getMapaUrl(String? value) {
    final val = value?.trim();
    if (val == null || val.isEmpty) return null;
    
    if (val.contains('<iframe')) {
      final regex = RegExp(r'src="([^"]+)"');
      final match = regex.firstMatch(val);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    if (val.startsWith('http')) {
      return val;
    }
    
    return null;
  }

  final result = getMapaUrl(iframe);
  print('Result: $result');
  
  if (result == 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d6167.645154916926!2d-45.88971545621486!3d-23.195598408446266!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x94cc4bc573d3cedb%3A0x1a06d2ea7c223489!2sEmporium%20da%20Arte!5e0!3m2!1spt-BR!2sbr!4v1774125143693!5m2!1spt-BR!2sbr') {
    print('SUCCESS');
  } else {
    print('FAILED');
  }
}

