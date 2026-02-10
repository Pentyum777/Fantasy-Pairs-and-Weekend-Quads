import 'package:http/http.dart' as http;

Future<void> main() async {
  const matchId = "CD_M20240180101";

  final fantasyRes = await http.get(
    Uri.parse("http://localhost:3000/fantasy/$matchId"),
  );
  final metaRes = await http.get(
    Uri.parse("http://localhost:3000/meta/$matchId"),
  );

  print("Fantasy: ${fantasyRes.body}");
  print("Meta: ${metaRes.body}");
}