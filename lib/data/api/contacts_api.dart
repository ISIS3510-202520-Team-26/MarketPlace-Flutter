import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart';
import '../../core/net/dio_client.dart';


class ContactsApi {
final _dio = DioClient.instance.dio;
Future<List<Map>> matchContacts() async {
if (!await FlutterContacts.requestPermission(readonly: true)) return [];
final contacts = await FlutterContacts.getContacts(withProperties: true);
final emails = <String>[];
for (final c in contacts) {
for (final e in c.emails) { emails.add(e.address.trim().toLowerCase()); }
}
final hashes = await compute(_hashEmails, emails);
final res = await _dio.post('/contacts/match', data: { 'email_hashes': hashes });
return (res.data as List).cast<Map>();
}
}


List<String> _hashEmails(List<String> emails) {
return emails.map((e) => sha256.convert(utf8.encode(e)).toString()).toList();
}