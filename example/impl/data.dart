import 'utils.dart';

class Data {
  Data(this.id);

  final int id;
}

Future<Data> loadData(int id) async {
  await randomDelay(factor: 100);
  return Data(id);
}
