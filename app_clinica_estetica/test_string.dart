
void main() {
  final ids = ['id1', 'id2', 'id3'];
  final formatted = '("${ids.join('","')}")';
  print('Formatted: $formatted');
  // Should be ("id1","id2","id3")
}

