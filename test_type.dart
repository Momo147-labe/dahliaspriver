void main() {
  List<int> trimestreValues = [1, 2, 3];
  final List<Map<String, dynamic>> trimestersList = trimestreValues.map((t) {
    String name = t == 1 ? "1er Trimestre" : "${t}ème Trimestre";
    return {'id': t, 'nom': name};
  }).toList();
  trimestersList.add({'id': 4, 'nom': 'Bilan Annuel'});
  print("Success");
}
