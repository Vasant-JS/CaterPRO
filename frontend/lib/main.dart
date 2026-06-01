import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() => runApp(const CaterProApp());

class CaterProApp extends StatelessWidget {
  const CaterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.quicksandTextTheme();
    return MaterialApp(
      title: 'CaterPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Cp.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Cp.primary,
          primary: Cp.primary,
          secondary: Cp.secondaryContainer,
          surface: Cp.surface,
          error: Cp.error,
        ),
        textTheme: textTheme.apply(bodyColor: Cp.onSurface, displayColor: Cp.onSurface),
      ),
      home: const AuthGate(),
    );
  }
}

class Cp {
  static const surface = Color(0xfff8f9fa);
  static const background = Color(0xfff8f9fa);
  static const card = Color(0xffffffff);
  static const surfaceLow = Color(0xfff3f4f5);
  static const surfaceHigh = Color(0xffe7e8e9);
  static const outline = Color(0xff72787f);
  static const outlineVariant = Color(0xffc1c7cf);
  static const onSurface = Color(0xff191c1d);
  static const onVariant = Color(0xff41474e);
  static const primary = Color(0xff003857);
  static const primaryContainer = Color(0xff1b4f72);
  static const primaryFixed = Color(0xffcce5ff);
  static const secondary = Color(0xff865300);
  static const secondaryContainer = Color(0xfffea520);
  static const secondaryFixed = Color(0xffffddb9);
  static const tertiary = Color(0xff003d1c);
  static const tertiaryContainer = Color(0xff00572a);
  static const tertiaryFixed = Color(0xff6bfe9c);
  static const error = Color(0xffba1a1a);
  static const errorContainer = Color(0xffffdad6);
}

class AdditionalServiceItem {
  const AdditionalServiceItem({required this.id, required this.name, required this.unit, required this.quantity, required this.price});
  final String id;
  final String name;
  final String unit;
  final int quantity;
  final int price;

  AdditionalServiceItem copyWith({String? id, String? name, String? unit, int? quantity, int? price}) {
    return AdditionalServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  factory AdditionalServiceItem.fromJson(Map<String, dynamic> json) {
    return AdditionalServiceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomMenu {
  const CustomMenu({required this.id, required this.name, required this.type, required this.itemIds});
  final String id;
  final String name;
  final String type;
  final Set<String> itemIds;

  factory CustomMenu.fromJson(Map<String, dynamic> json) {
    return CustomMenu(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      itemIds: ((json['itemIds'] as List?) ?? []).map((item) => item.toString()).toSet(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'itemIds': itemIds.toList()};
}

class BusinessProfile {
  const BusinessProfile({
    this.businessName = '',
    this.serviceType = '',
    this.gstin = '',
    this.pan = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.bankName = '',
    this.accountNumber = '',
    this.terms = '',
    this.logoBase64 = '',
    this.signatureBase64 = '',
    this.qrBase64 = '',
    this.documentTemplate = 'modern',
  });

  final String businessName;
  final String serviceType;
  final String gstin;
  final String pan;
  final String address;
  final String phone;
  final String email;
  final String bankName;
  final String accountNumber;
  final String terms;
  final String logoBase64;
  final String signatureBase64;
  final String qrBase64;
  final String documentTemplate;

  factory BusinessProfile.fromJson(Map<String, dynamic>? json) {
    final data = json ?? {};
    return BusinessProfile(
      businessName: data['businessName']?.toString() ?? '',
      serviceType: data['serviceType']?.toString() ?? '',
      gstin: data['gstin']?.toString() ?? '',
      pan: data['pan']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      bankName: data['bankName']?.toString() ?? '',
      accountNumber: data['accountNumber']?.toString() ?? '',
      terms: data['terms']?.toString() ?? '',
      logoBase64: data['logoBase64']?.toString() ?? '',
      signatureBase64: data['signatureBase64']?.toString() ?? '',
      qrBase64: data['qrBase64']?.toString() ?? '',
      documentTemplate: data['documentTemplate']?.toString() ?? 'modern',
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'serviceType': serviceType,
        'gstin': gstin,
        'pan': pan,
        'address': address,
        'phone': phone,
        'email': email,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'terms': terms,
        'logoBase64': logoBase64,
        'signatureBase64': signatureBase64,
        'qrBase64': qrBase64,
        'documentTemplate': documentTemplate,
      };
}

class ApiConfig {
  static const _definedBaseUrl = String.fromEnvironment('CATERPRO_API_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8787/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787/api';
    }
    return 'http://127.0.0.1:8787/api';
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.userId, required this.email, required this.name});
  final String token;
  final String userId;
  final String email;
  final String name;
}

class AuthService {
  Future<AuthSession?> savedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token');
    final userId = prefs.getString('auth.userId');
    final email = prefs.getString('auth.email');
    final name = prefs.getString('auth.name');
    if (token == null || token.isEmpty || userId == null || email == null || name == null) return null;
    return AuthSession(token: token, userId: userId, email: email, name: name);
  }

  Future<AuthSession> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Login failed');
    }
    final user = body['user'] as Map<String, dynamic>;
    final session = AuthSession(token: body['token'] as String, userId: user['id'] as String, email: user['email'] as String, name: user['name'] as String);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth.token', session.token);
    await prefs.setString('auth.userId', session.userId);
    await prefs.setString('auth.email', session.email);
    await prefs.setString('auth.name', session.name);
    return session;
  }

  Future<void> forgotPassword(String email) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth.token');
    await prefs.remove('auth.userId');
    await prefs.remove('auth.email');
    await prefs.remove('auth.name');
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthService();
  bool checking = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final session = await auth.savedSession();
    if (!mounted) return;
    setState(() {
      loggedIn = session != null;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Cp.primary)));
    }
    return loggedIn ? const AppShell() : const LoginScreen();
  }
}

class AppEvent {
  const AppEvent({required this.id, required this.name, required this.primaryClient, required this.mobile, required this.venue, required this.notes, required this.status, required this.addOns, required this.dates, required this.payments, required this.materialDocuments, required this.employeeAssignments});
  final String id;
  final String name;
  final String primaryClient;
  final String mobile;
  final String venue;
  final String notes;
  final String status;
  final List<Map<String, dynamic>> addOns;
  final List<AppEventDate> dates;
  final List<AppPayment> payments;
  final List<EventMaterialDocument> materialDocuments;
  final List<EventEmployeeAssignment> employeeAssignments;

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      primaryClient: json['primaryClient'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      addOns: ((json['addOns'] as List?) ?? []).whereType<Map<String, dynamic>>().toList(),
      dates: ((json['dates'] as List?) ?? []).whereType<Map<String, dynamic>>().map(AppEventDate.fromJson).toList(),
      payments: ((json['payments'] as List?) ?? []).whereType<Map<String, dynamic>>().map(AppPayment.fromJson).toList(),
      materialDocuments: ((json['materialDocuments'] as List?) ?? []).whereType<Map<String, dynamic>>().map(EventMaterialDocument.fromJson).toList(),
      employeeAssignments: ((json['employeeAssignments'] as List?) ?? []).whereType<Map<String, dynamic>>().map(EventEmployeeAssignment.fromJson).toList(),
    );
  }
}

class EventEmployeeAssignment {
  const EventEmployeeAssignment({required this.employeeId, required this.employeeName, required this.mobile, required this.designation, required this.payPerDay});
  final String employeeId;
  final String employeeName;
  final String mobile;
  final String designation;
  final int payPerDay;

  factory EventEmployeeAssignment.fromJson(Map<String, dynamic> json) => EventEmployeeAssignment(
        employeeId: json['employeeId']?.toString() ?? json['id']?.toString() ?? '',
        employeeName: json['employeeName']?.toString() ?? json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {'employeeId': employeeId, 'employeeName': employeeName, 'mobile': mobile, 'designation': designation, 'payPerDay': payPerDay};
}

class AppClient {
  const AppClient({required this.id, required this.name, required this.mobile, this.city = '', this.notes = '', this.address = '', this.gst = ''});
  final String id;
  final String name;
  final String mobile;
  final String city;
  final String notes;
  final String address;
  final String gst;

  factory AppClient.fromJson(Map<String, dynamic> json) => AppClient(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        gst: json['gst']?.toString() ?? json['gstin']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mobile': mobile, 'city': city, 'notes': notes, 'address': address, 'gst': gst};

  AppClient copyWith({String? id, String? name, String? mobile, String? city, String? notes, String? address, String? gst}) => AppClient(
        id: id ?? this.id,
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        city: city ?? this.city,
        notes: notes ?? this.notes,
        address: address ?? this.address,
        gst: gst ?? this.gst,
      );
}

class Employee {
  const Employee({required this.id, required this.name, required this.age, required this.mobile, required this.designation, required this.payPerDay});
  final String id;
  final String name;
  final int age;
  final String mobile;
  final String designation;
  final int payPerDay;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
        mobile: json['mobile']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
      );

  factory Employee.fromAssignment(EventEmployeeAssignment assignment) => Employee(
        id: assignment.employeeId,
        name: assignment.employeeName,
        age: 0,
        mobile: assignment.mobile,
        designation: assignment.designation,
        payPerDay: assignment.payPerDay,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'age': age, 'mobile': mobile, 'designation': designation, 'payPerDay': payPerDay};

  Employee copyWith({String? id, String? name, int? age, String? mobile, String? designation, int? payPerDay}) => Employee(
        id: id ?? this.id,
        name: name ?? this.name,
        age: age ?? this.age,
        mobile: mobile ?? this.mobile,
        designation: designation ?? this.designation,
        payPerDay: payPerDay ?? this.payPerDay,
      );
}

class AttendanceRecord {
  const AttendanceRecord({required this.id, required this.employeeId, required this.employeeName, required this.eventId, required this.eventName, required this.date, required this.status, required this.hours, required this.payPerDay});
  final String id;
  final String employeeId;
  final String employeeName;
  final String eventId;
  final String eventName;
  final String date;
  final String status;
  final double hours;
  final int payPerDay;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id']?.toString() ?? '',
        employeeId: json['employeeId']?.toString() ?? '',
        employeeName: json['employeeName']?.toString() ?? '',
        eventId: json['eventId']?.toString() ?? '',
        eventName: json['eventName']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        status: json['status']?.toString() ?? 'absent',
        hours: double.tryParse(json['hours']?.toString() ?? '') ?? 0,
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'employeeId': employeeId, 'employeeName': employeeName, 'eventId': eventId, 'eventName': eventName, 'date': date, 'status': status, 'hours': hours, 'payPerDay': payPerDay};
}

class EventMaterialLine {
  const EventMaterialLine({required this.itemId, required this.name, required this.category, required this.quantity, required this.unit});
  final String itemId;
  final String name;
  final String category;
  final String quantity;
  final String unit;

  factory EventMaterialLine.fromJson(Map<String, dynamic> json) => EventMaterialLine(
        itemId: json['itemId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        quantity: json['quantity']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'itemId': itemId, 'name': name, 'category': category, 'quantity': quantity, 'unit': unit};
}

class EventMaterialDocument {
  const EventMaterialDocument({required this.id, required this.type, required this.title, required this.items});
  final String id;
  final String type;
  final String title;
  final List<EventMaterialLine> items;

  String get typeLabel => type == 'produce' ? 'Vegetables & Fruits' : 'Raw Materials';

  factory EventMaterialDocument.fromJson(Map<String, dynamic> json) => EventMaterialDocument(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'raw',
        title: json['title']?.toString() ?? '',
        items: ((json['items'] as List?) ?? []).whereType<Map<String, dynamic>>().map(EventMaterialLine.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'title': title, 'items': items.map((item) => item.toJson()).toList()};
}

class AppPayment {
  const AppPayment({required this.id, required this.amount, required this.date, required this.mode, required this.reference, required this.settled, required this.settledDiscount});
  final String id;
  final int amount;
  final String date;
  final String mode;
  final String reference;
  final bool settled;
  final int settledDiscount;

  factory AppPayment.fromJson(Map<String, dynamic> json) {
    return AppPayment(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      settled: json['settled'] == true,
      settledDiscount: (json['settledDiscount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ManualInvoiceItem {
  const ManualInvoiceItem({required this.id, required this.title, required this.quantity, required this.rate, required this.amount});
  final String id;
  final String title;
  final int quantity;
  final int rate;
  final int amount;

  factory ManualInvoiceItem.fromJson(Map<String, dynamic> json) => ManualInvoiceItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'quantity': quantity, 'rate': rate, 'amount': amount};
}

class ManualInvoice {
  const ManualInvoice({
    required this.id,
    required this.clientName,
    required this.mobile,
    this.clientAddress = '',
    this.clientGst = '',
    required this.eventName,
    required this.venue,
    required this.eventDate,
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.notes,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.advance,
    required this.settlement,
    required this.pending,
  });
  final String id;
  final String clientName;
  final String mobile;
  final String clientAddress;
  final String clientGst;
  final String eventName;
  final String venue;
  final String eventDate;
  final String invoiceDate;
  final String invoiceNumber;
  final String notes;
  final List<ManualInvoiceItem> items;
  final int subtotal;
  final int total;
  final int advance;
  final int settlement;
  final int pending;

  factory ManualInvoice.fromJson(Map<String, dynamic> json) => ManualInvoice(
        id: json['id']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        clientAddress: json['clientAddress']?.toString() ?? '',
        clientGst: json['clientGst']?.toString() ?? '',
        eventName: json['eventName']?.toString() ?? '',
        venue: json['venue']?.toString() ?? '',
        eventDate: json['eventDate']?.toString() ?? '',
        invoiceDate: json['invoiceDate']?.toString() ?? '',
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        items: ((json['items'] as List?) ?? []).whereType<Map<String, dynamic>>().map(ManualInvoiceItem.fromJson).toList(),
        subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        advance: (json['advance'] as num?)?.toInt() ?? 0,
        settlement: (json['settlement'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'mobile': mobile,
        'clientAddress': clientAddress,
        'clientGst': clientGst,
        'eventName': eventName,
        'venue': venue,
        'eventDate': eventDate,
        'invoiceDate': invoiceDate,
        'invoiceNumber': invoiceNumber,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'total': total,
        'advance': advance,
        'settlement': settlement,
        'pending': pending,
      };
}

class AppEventDate {
  const AppEventDate({required this.id, required this.date, required this.label, required this.menuSlots, required this.additionalServices});
  final String id;
  final String date;
  final String label;
  final List<AppMenuSlot> menuSlots;
  final List<Map<String, dynamic>> additionalServices;

  factory AppEventDate.fromJson(Map<String, dynamic> json) {
    return AppEventDate(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      label: json['label'] as String? ?? '',
      menuSlots: ((json['menuSlots'] as List?) ?? []).whereType<Map<String, dynamic>>().map(AppMenuSlot.fromJson).toList(),
      additionalServices: ((json['additionalServices'] as List?) ?? []).whereType<Map<String, dynamic>>().toList(),
    );
  }
}

class AppMenuSlot {
  const AppMenuSlot({required this.id, required this.type, required this.time, required this.pax, required this.pricePerPax, required this.enabled, required this.menuItemIds});
  final String id;
  final String type;
  final String time;
  final int pax;
  final int pricePerPax;
  final bool enabled;
  final List<String> menuItemIds;

  factory AppMenuSlot.fromJson(Map<String, dynamic> json) {
    return AppMenuSlot(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      pax: (json['pax'] as num?)?.toInt() ?? 0,
      pricePerPax: (json['pricePerPax'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] != false,
      menuItemIds: ((json['menuItemIds'] as List?) ?? []).map((item) => item.toString()).toList(),
    );
  }
}

class ApiService {
  Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<List<AppEvent>> getEvents() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/events'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load events');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(AppEvent.fromJson).toList();
  }

  Future<AppEvent> getEvent(String eventId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/events/$eventId'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load event');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MenuMasterItem>> getMenuItems() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/menu-items'));
    if (response.statusCode != 200) throw Exception('Unable to load menu items');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(MenuMasterItem.fromJson).toList();
  }

  Future<List<RawMaterialItem>> getRawMaterials() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/raw-materials'));
    if (response.statusCode != 200) throw Exception('Unable to load raw materials');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(RawMaterialItem.fromJson).toList();
  }

  Future<RawMaterialItem> saveRawMaterial(RawMaterialItem item) async {
    final creating = item.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/raw-materials${creating ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save raw material');
    return RawMaterialItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RawMaterialItem>> getProduceItems() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/produce-items'));
    if (response.statusCode != 200) throw Exception('Unable to load vegetables and fruits');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(RawMaterialItem.fromJson).toList();
  }

  Future<RawMaterialItem> saveProduceItem(RawMaterialItem item) async {
    final creating = item.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/produce-items${creating ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save vegetable/fruit item');
    return RawMaterialItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AdditionalServiceItem>> getAdditionalServices() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/bootstrap'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load additional services');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final userData = (body['userData'] as Map?) ?? {};
    return ((userData['additionalServices'] as List?) ?? []).whereType<Map<String, dynamic>>().map(AdditionalServiceItem.fromJson).toList();
  }

  Future<BusinessProfile> getBusinessProfile() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/business-profile'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load business profile');
    return BusinessProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<BusinessProfile> saveBusinessProfile(BusinessProfile profile) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/business-profile'),
      headers: await authHeaders(),
      body: jsonEncode(profile.toJson()),
    );
    if (response.statusCode != 200) throw Exception('Unable to save business profile');
    return BusinessProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AppClient>> getClients() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/clients'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load clients');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(AppClient.fromJson).toList();
  }

  Future<AppClient> saveClient(AppClient client) async {
    final creating = client.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/clients${creating ? '' : '/${client.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(client.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save client');
    return AppClient.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteClient(String id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/clients/$id'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to delete client');
  }

  Future<List<Employee>> getEmployees() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/employees'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load employees');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(Employee.fromJson).toList();
  }

  Future<Employee> saveEmployee(Employee employee) async {
    final creating = employee.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/employees${creating ? '' : '/${employee.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(employee.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save employee');
    return Employee.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(String id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/employees/$id'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to delete employee');
  }

  Future<AppEvent> saveEventEmployeeAssignments(String eventId, List<EventEmployeeAssignment> assignments) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/events/$eventId/employee-assignments'),
      headers: await authHeaders(),
      body: jsonEncode({'employeeAssignments': assignments.map((item) => item.toJson()).toList()}),
    );
    if (response.statusCode != 200) throw Exception('Unable to save employee assignments');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AttendanceRecord>> getAttendance({String? month, String? eventId}) async {
    final query = <String, String>{};
    if (month != null && month.isNotEmpty) query['month'] = month;
    if (eventId != null && eventId.isNotEmpty) query['eventId'] = eventId;
    final uri = Uri.parse('${ApiConfig.baseUrl}/attendance').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load attendance');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(AttendanceRecord.fromJson).toList();
  }

  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/attendance'),
      headers: await authHeaders(),
      body: jsonEncode(record.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save attendance');
    return AttendanceRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uri> attendancePdfUri(String month) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/attendance/monthly.pdf').replace(queryParameters: {'token': token, 'month': month});
  }

  Future<List<CustomMenu>> getCustomMenus() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/custom-menus'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load custom menus');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(CustomMenu.fromJson).toList();
  }

  Future<CustomMenu> saveCustomMenu(CustomMenu menu) async {
    final creating = menu.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/custom-menus${creating ? '' : '/${menu.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(menu.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save custom menu');
    return CustomMenu.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppEvent> createEvent(EventDraft draft) async {
    final headers = await authHeaders();
    final eventResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/events'),
      headers: headers,
      body: jsonEncode({'name': draft.name, 'primaryClient': draft.client, 'mobile': draft.mobile, 'venue': draft.venue, 'notes': draft.notes, 'status': 'draft', 'addOns': draft.addOns}),
    );
    if (eventResponse.statusCode != 201) throw Exception('Unable to create event');
    final event = jsonDecode(eventResponse.body) as Map<String, dynamic>;
    final eventId = event['id'] as String;

    for (final dateConfig in draft.dates) {
      final dateResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId/dates'),
        headers: headers,
        body: jsonEncode({'date': dateConfig.date, 'label': dateConfig.label}),
      );
      if (dateResponse.statusCode != 201) throw Exception('Unable to add event date');
      final date = jsonDecode(dateResponse.body) as Map<String, dynamic>;
      final dateId = date['id'] as String;
      for (final slot in dateConfig.slots) {
        if (!slot.enabled) continue;
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/events/$eventId/dates/$dateId/menu-slots'),
          headers: headers,
          body: jsonEncode({'type': slot.type, 'time': slot.time, 'pax': int.tryParse(slot.pax) ?? 0, 'pricePerPax': slot.pricePerPax, 'enabled': slot.enabled, 'menuItemIds': slot.selectedMenuIds.toList()}),
        );
      }
      for (final service in dateConfig.additionalServices) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/events/$eventId/dates/$dateId/additional-services'),
          headers: headers,
          body: jsonEncode(service),
        );
      }
    }
    final loaded = await http.get(Uri.parse('${ApiConfig.baseUrl}/events/$eventId'), headers: headers);
    return AppEvent.fromJson(jsonDecode(loaded.body) as Map<String, dynamic>);
  }

  Future<AppEvent> saveEventDraft(EventDraft draft, {String? eventId}) async {
    final headers = await authHeaders();
    final body = jsonEncode(draft.toJson());
    final response = eventId == null || eventId.isEmpty
        ? await http.post(Uri.parse('${ApiConfig.baseUrl}/events'), headers: headers, body: body)
        : await http.put(Uri.parse('${ApiConfig.baseUrl}/events/$eventId'), headers: headers, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save event draft');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppEvent> recordPayment(String eventId, {required int amount, required String date, required String mode, required String reference, required bool settled, required int settledDiscount}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/events/$eventId/payments'),
      headers: await authHeaders(),
      body: jsonEncode({'amount': amount, 'date': date, 'mode': mode, 'reference': reference, 'settled': settled, 'settledDiscount': settledDiscount}),
    );
    if (response.statusCode != 201) throw Exception('Unable to save payment');
    return getEvent(eventId);
  }

  Future<List<ManualInvoice>> getManualInvoices() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/manual-invoices'), headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load manual invoices');
    return (jsonDecode(response.body) as List).whereType<Map<String, dynamic>>().map(ManualInvoice.fromJson).toList();
  }

  Future<ManualInvoice> saveManualInvoice(ManualInvoice invoice) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/manual-invoices'),
      headers: await authHeaders(),
      body: jsonEncode(invoice.toJson()),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body is Map && body['message'] != null ? body['message'] : 'Unable to save invoice');
    }
    return ManualInvoice.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uri> manualInvoicePdfUri(String invoiceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/manual-invoices/$invoiceId/pdf').replace(queryParameters: {'token': token});
  }

  Future<AppEvent> saveMaterialDocument(String eventId, EventMaterialDocument document) async {
    final creating = document.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse('${ApiConfig.baseUrl}/events/$eventId/material-documents${creating ? '' : '/${document.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(document.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Unable to save material document');
    return getEvent(eventId);
  }

  Future<Uri> documentUri(String eventId, String type, {String? dateId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    final query = <String, String>{'token': token};
    if (dateId != null && dateId.isNotEmpty) query['dateId'] = dateId;
    return Uri.parse('${ApiConfig.baseUrl}/events/$eventId/documents/$type').replace(queryParameters: query);
  }

  Future<Uri> upcomingMenusUri({int days = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/documents/upcoming-menus').replace(queryParameters: {'token': token, 'days': '$days'});
  }

  Future<String?> upcomingMenusError({int days = 3}) async {
    final uri = await upcomingMenusUri(days: days);
    final response = await http.get(uri, headers: await authHeaders());
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      return contentType.toLowerCase().contains('application/pdf') ? null : 'Upcoming menu is not available yet.';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) return body['message'].toString();
    } catch (_) {
      // Fall through to the friendly default below.
    }
    return 'No upcoming menus found';
  }

  Future<Uri> materialDocumentPdfUri(String eventId, String documentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/events/$eventId/material-documents/$documentId/pdf').replace(queryParameters: {'token': token});
  }
}

String money(int value) => '₹${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
String normalizeMobileText(String value) => value.trim().replaceFirst(RegExp(r'^\+91\s*'), '').replaceAll(RegExp(r'\D'), '');
bool isValidEmail(String value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
String? requiredTextValidator(String? value, String label) => (value ?? '').trim().isEmpty ? '$label is required' : null;
String? mobileValidator(String? value, {String label = 'Mobile number', bool required = true}) {
  final clean = normalizeMobileText(value ?? '');
  if (clean.isEmpty && !required) return null;
  return clean.length == 10 ? null : '$label must be 10 digits';
}
String? emailValidator(String? value, {String label = 'Email', bool required = true}) {
  final text = (value ?? '').trim();
  if (text.isEmpty && !required) return null;
  return isValidEmail(text) ? null : 'Enter a valid $label';
}
String? isoDateValidator(String? value, {String label = 'Date', bool required = true, bool noPast = false}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return required ? '$label is required' : null;
  final parsed = parseIsoDate(text);
  if (parsed == null) return 'Enter $label as YYYY-MM-DD';
  if (noPast) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (parsed.isBefore(today)) return '$label cannot be in the past';
  }
  return null;
}
String? positiveMoneyValidator(String? value, String label, {bool required = true, bool allowZero = false}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return required ? '$label is required' : null;
  final amount = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  if (amount == null) return 'Enter a valid $label';
  if (allowZero ? amount < 0 : amount <= 0) return allowZero ? '$label cannot be negative' : '$label must be more than zero';
  return null;
}
final mobileInputFormatters = <TextInputFormatter>[
  TextInputFormatter.withFunction((oldValue, newValue) {
    final clean = normalizeMobileNumber(newValue.text);
    final capped = clean.length > 10 ? clean.substring(0, 10) : clean;
    return TextEditingValue(text: capped, selection: TextSelection.collapsed(offset: capped.length));
  }),
];

String serviceLine(String name, Object? quantity, Object? unit, Object? price) {
  final count = quantity is num ? quantity.toInt() : int.tryParse(quantity?.toString() ?? '') ?? 0;
  final amount = price is num ? price.toInt() : int.tryParse(price?.toString() ?? '') ?? 0;
  final parts = <String>[];
  if (count > 0) parts.add('$count ${unit?.toString() ?? ''}'.trim());
  if (amount > 0) parts.add(money(amount));
  return parts.isEmpty ? name : '$name\n${parts.join(' • ')}';
}

String additionalServiceLine(Map<String, dynamic> service) => serviceLine(service['name']?.toString() ?? '', service['quantity'], service['unit'], service['price']);
String addOnLine(Map<String, dynamic> addOn) => '${addOn['title']?.toString() ?? 'Add-on'}\n${money((addOn['cost'] as num?)?.toInt() ?? 0)}';

int eventMenuTotal(AppEvent event) => event.dates.fold(0, (dateSum, date) => dateSum + date.menuSlots.fold(0, (slotSum, slot) => slotSum + slot.pax * slot.pricePerPax));
int eventServiceTotal(AppEvent event) => event.dates.fold(0, (dateSum, date) => dateSum + date.additionalServices.fold(0, (sum, service) => sum + ((service['price'] as num?)?.toInt() ?? 0)));
int eventAddOnTotal(AppEvent event) => event.addOns.fold(0, (sum, addOn) => sum + ((addOn['cost'] as num?)?.toInt() ?? 0));
int eventTotal(AppEvent event) => eventMenuTotal(event) + eventServiceTotal(event) + eventAddOnTotal(event);
int eventPaid(AppEvent event) => event.payments.fold(0, (sum, payment) => sum + payment.amount);
int eventSettledDiscount(AppEvent event) => event.payments.fold(0, (sum, payment) => sum + payment.settledDiscount);
int eventBalance(AppEvent event) => (eventTotal(event) - eventPaid(event) - eventSettledDiscount(event)).clamp(0, eventTotal(event));
bool eventIsIncomplete(AppEvent event) {
  final hasDetails = event.name.trim().isNotEmpty && event.mobile.trim().isNotEmpty && event.primaryClient.trim().isNotEmpty;
  final hasDates = event.dates.isNotEmpty;
  final hasMenu = event.dates.any((date) => date.menuSlots.isNotEmpty);
  return !hasDetails || !hasDates || !hasMenu;
}

class EventDraft {
  String? id;
  String name = '';
  String client = '';
  String mobile = '';
  String venue = '';
  String notes = '';
  final List<Map<String, dynamic>> addOns = [];
  final List<DraftDateConfig> dates = [];

  EventDraft();

  factory EventDraft.fromEvent(AppEvent event) {
    final draft = EventDraft()
      ..id = event.id
      ..name = event.name
      ..client = event.primaryClient
      ..mobile = event.mobile
      ..venue = event.venue
      ..notes = event.notes;
    draft.addOns.addAll(event.addOns.map((addOn) => Map<String, dynamic>.from(addOn)));
    draft.dates.addAll(event.dates.map(DraftDateConfig.fromEventDate));
    return draft;
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'name': name,
        'primaryClient': client,
        'mobile': mobile,
        'venue': venue,
        'notes': notes,
        'status': 'draft',
        'addOns': addOns,
        'dates': dates.map((date) => date.toJson()).toList(),
      };
}

String normalizeMobileNumber(String value) {
  final text = normalizeMobileText(value);
  if (text.startsWith('91') && text.length == 12) return text.substring(2);
  return text;
}

class CustomerSuggestion {
  const CustomerSuggestion({required this.name, required this.mobile});
  final String name;
  final String mobile;
}

const _monthShortNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

DateTime? parseIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null || month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String shortMonthLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null ? '--' : _monthShortNames[date.month - 1];
}

String dayLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null ? '--' : date.day.toString().padLeft(2, '0');
}

String readableDateLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null ? isoDate : '${date.day.toString().padLeft(2, '0')} ${_monthShortNames[date.month - 1]} ${date.year}';
}

class DraftDateConfig {
  DraftDateConfig({this.id, required this.date, this.label = ''});
  String? id;
  String date;
  String label;
  final List<MealSlotConfig> slots = [];
  final List<Map<String, dynamic>> additionalServices = [];

  factory DraftDateConfig.fromEventDate(AppEventDate date) {
    final config = DraftDateConfig(id: date.id, date: date.date, label: date.label);
    config.slots.addAll(date.menuSlots.map(MealSlotConfig.fromEventSlot));
    config.additionalServices.addAll(date.additionalServices.map((service) => Map<String, dynamic>.from(service)));
    return config;
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'date': date,
        'label': label,
        'menuSlots': slots.map((slot) => slot.toJson()).toList(),
        'additionalServices': additionalServices,
      };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final authService = AuthService();
  final email = TextEditingController(text: 'admin@caterpro.in');
  final password = TextEditingController(text: 'password');
  bool obscurePassword = true;
  bool rememberMe = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final emailText = email.text.trim();
    final passwordText = password.text;
    if (!(formKey.currentState?.validate() ?? false)) {
      setState(() => error = 'Enter a valid email and password.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await authService.login(email: emailText, password: passwordText);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void fingerprintLogin() {
    showCpSnack(context, 'Fingerprint authenticated');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  Future<void> forgotPassword() async {
    final emailText = email.text.trim();
    if (emailValidator(emailText) != null) {
      showCpSnack(context, 'Enter your email to receive reset link');
      return;
    }
    try {
      await authService.forgotPassword(emailText);
      if (!mounted) return;
      showCpSnack(context, 'Reset link sent to $emailText');
    } catch (_) {
      if (!mounted) return;
      showCpSnack(context, 'Backend is not reachable. Start CaterPro API.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cp.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            const SizedBox(height: 18),
            Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Cp.primaryContainer, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 26),
            const Text('CaterPro', style: TextStyle(color: Cp.primary, fontSize: 38, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Sign in to manage events, menus, billing, and teams.', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 28),
            Form(
              key: formKey,
              child: CpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Login', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  validator: emailValidator,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.email_outlined), labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: password,
                  obscureText: obscurePassword,
                  validator: (value) => (value ?? '').length < 4 ? 'Password must be at least 4 characters' : null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Checkbox(value: rememberMe, activeColor: Cp.primary, onChanged: (value) => setState(() => rememberMe = value ?? false)),
                  const Expanded(child: Text('Remember me', style: TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(onPressed: forgotPassword, child: const Text('Forgot Password?', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900))),
                ]),
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
                SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: loading ? null : login, style: FilledButton.styleFrom(backgroundColor: Cp.primary), icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: Text(loading ? 'Logging in...' : 'Login', style: const TextStyle(fontWeight: FontWeight.w900)))),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: fingerprintLogin,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text('Authenticate with Fingerprint', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final api = ApiService();
  int tab = 0;
  bool loading = true;
  String? loadError;
  final List<AppEvent> events = [];
  final List<AppClient> clients = [];
  final List<Employee> employees = [];
  final List<ManualInvoice> manualInvoices = [];
  final List<AdditionalServiceItem> services = [];
  final List<CustomMenu> customMenus = [];
  BusinessProfile businessProfile = const BusinessProfile();
  String? selectedEventId;
  AppEvent? editingEvent;
  int createSession = 0;

  @override
  void initState() {
    super.initState();
    refreshEvents();
  }

  Future<void> refreshEvents() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final loaded = await api.getEvents();
      final loadedClients = await api.getClients();
      final loadedEmployees = await api.getEmployees();
      final loadedManualInvoices = await api.getManualInvoices();
      final menuItems = await api.getMenuItems();
      final additionalServices = await api.getAdditionalServices();
      final loadedCustomMenus = await api.getCustomMenus();
      final loadedBusinessProfile = await api.getBusinessProfile();
      if (!mounted) return;
      setState(() {
        events
          ..clear()
          ..addAll(loaded);
        clients
          ..clear()
          ..addAll(loadedClients);
        employees
          ..clear()
          ..addAll(loadedEmployees);
        manualInvoices
          ..clear()
          ..addAll(loadedManualInvoices);
        MenuMasterScreen.menuItems
          ..clear()
          ..addAll(menuItems);
        services
          ..clear()
          ..addAll(additionalServices);
        customMenus
          ..clear()
          ..addAll(loadedCustomMenus);
        businessProfile = loadedBusinessProfile;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createEvent(EventDraft draft) async {
    final event = await api.saveEventDraft(draft, eventId: draft.id);
    setState(() {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index == -1) {
        events.add(event);
      } else {
        events[index] = event;
      }
      selectedEventId = event.id;
      tab = 1;
      editingEvent = null;
    });
  }

  Future<void> saveManualInvoice(ManualInvoice invoice) async {
    final saved = await api.saveManualInvoice(invoice);
    setState(() {
      final index = manualInvoices.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        manualInvoices.add(saved);
      } else {
        manualInvoices[index] = saved;
      }
      tab = 3;
    });
  }

  Future<void> saveClient(AppClient client) async {
    final saved = await api.saveClient(client.copyWith(mobile: normalizeMobileText(client.mobile)));
    setState(() {
      final index = clients.indexWhere((item) => item.id == saved.id || normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        clients.add(saved);
      } else {
        clients[index] = saved;
      }
    });
  }

  Future<void> deleteClient(AppClient client) async {
    if (client.id.isNotEmpty) await api.deleteClient(client.id);
    setState(() => clients.removeWhere((item) => item.id == client.id || normalizeMobileText(item.mobile) == normalizeMobileText(client.mobile)));
  }

  Future<void> saveEmployee(Employee employee) async {
    final saved = await api.saveEmployee(employee.copyWith(mobile: normalizeMobileText(employee.mobile)));
    setState(() {
      final index = employees.indexWhere((item) => item.id == saved.id || normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        employees.add(saved);
      } else {
        employees[index] = saved;
      }
    });
  }

  Future<void> deleteEmployee(Employee employee) async {
    if (employee.id.isNotEmpty) await api.deleteEmployee(employee.id);
    setState(() => employees.removeWhere((item) => item.id == employee.id || normalizeMobileText(item.mobile) == normalizeMobileText(employee.mobile)));
  }

  Future<void> openManualInvoiceForm() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManualInvoiceFormScreen(clients: clients, onSave: saveManualInvoice)));
    if (mounted) setState(() => tab = 3);
  }

  void openEventDetails(AppEvent event) {
    setState(() {
      selectedEventId = event.id;
      tab = 6;
    });
  }

  void updateSelectedEvent(AppEvent event) {
    setState(() {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index == -1) {
        events.add(event);
      } else {
        events[index] = event;
      }
      selectedEventId = event.id;
    });
  }

  void openCreateEvent() {
    setState(() {
      editingEvent = null;
      selectedEventId = null;
      createSession++;
      tab = 5;
    });
  }

  void openEditEvent(AppEvent event) {
    setState(() {
      editingEvent = event;
      selectedEventId = event.id;
      createSession++;
      tab = 5;
    });
  }

  void upsertService(AdditionalServiceItem service) {
    setState(() {
      final index = services.indexWhere((item) => item.id == service.id);
      if (index == -1) {
        services.add(service);
      } else {
        services[index] = service;
      }
    });
  }

  void removeService(String id) {
    setState(() => services.removeWhere((item) => item.id == id));
  }

  Future<void> saveCustomMenu(CustomMenu menu) async {
    final saved = await api.saveCustomMenu(menu);
    setState(() {
      final index = customMenus.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        customMenus.add(saved);
      } else {
        customMenus[index] = saved;
      }
    });
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    final saved = await api.saveBusinessProfile(profile);
    setState(() => businessProfile = saved);
  }

  List<Widget> get pages => <Widget>[
    DashboardScreen(api: api, events: events, loading: loading, loadError: loadError, openCreate: openCreateEvent, openDetails: openEventDetails, refresh: refreshEvents),
    EventsScreen(events: events, loading: loading, loadError: loadError, openDetails: openEventDetails, openCreate: openCreateEvent, refresh: refreshEvents),
    ClientsScreen(clients: clients, events: events, manualInvoices: manualInvoices, onSaveClient: saveClient, onDeleteClient: deleteClient, openEvent: openEventDetails),
    BillingScreen(events: events, manualInvoices: manualInvoices, api: api, onSaveManualInvoice: saveManualInvoice, onAddManualInvoice: openManualInvoiceForm),
    SettingsScreen(openBusiness: () => setState(() => tab = 8), openMenu: () => setState(() => tab = 7), openCustomMenus: () => setState(() => tab = 11), openEmployees: () => setState(() => tab = 9), openRawMaterials: () => setState(() => tab = 10), openProduceItems: () => setState(() => tab = 12), businessProfile: businessProfile, services: services, onSaveService: upsertService, onDeleteService: removeService),
    CreateEventScreen(key: ValueKey('create-$createSession-${editingEvent?.id ?? 'new'}'), initialEvent: editingEvent, onDraftSaved: updateSelectedEvent, onClose: () => setState(() { editingEvent = null; tab = 1; }), onCreate: createEvent, services: services, customMenus: customMenus, customerEvents: events, onSaveService: upsertService, onDeleteService: removeService),
    EventDetailsScreen(event: events.where((event) => event.id == selectedEventId).firstOrNull, api: api, employees: employees, onEdit: openEditEvent, onEventUpdated: updateSelectedEvent, onClose: () => setState(() => tab = 1)),
    MenuMasterScreen(onClose: () => setState(() => tab = 4)),
    BusinessProfileScreen(profile: businessProfile, onSave: saveBusinessProfile, onClose: () => setState(() => tab = 4)),
    EmployeeScreen(api: api, employees: employees, onSave: saveEmployee, onDelete: deleteEmployee, onClose: () => setState(() => tab = 4)),
    RawMaterialScreen(onClose: () => setState(() => tab = 4)),
    CustomMenuScreen(onClose: () => setState(() => tab = 4), customMenus: customMenus, onSave: saveCustomMenu),
    ProduceItemScreen(onClose: () => setState(() => tab = 4)),
  ];

  @override
  Widget build(BuildContext context) {
    final showNav = tab < 5;
    return Scaffold(
      drawer: showNav ? CaterSideDrawer(index: tab, onChanged: (i) => setState(() => tab = i)) : null,
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: showNav ? _fabForTab() : null,
    );
  }

  Widget? _fabForTab() {
    final icons = [Icons.add, Icons.add, Icons.add, Icons.add, null];
    if (icons[tab] == null) return null;
    return FloatingActionButton(
      backgroundColor: Cp.secondaryContainer,
      foregroundColor: Color(0xff694000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        if (tab == 0 || tab == 1) {
          openCreateEvent();
        } else if (tab == 3) {
          openManualInvoiceForm();
        } else {
          showCpSnack(context, 'Add from this section will be enabled soon');
        }
      },
      child: Icon(icons[tab]),
    );
  }
}

class CaterSideDrawer extends StatelessWidget {
  const CaterSideDrawer({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    (Icons.home_rounded, 'Dashboard'),
    (Icons.calendar_month_rounded, 'Events'),
    (Icons.group_rounded, 'Clients'),
    (Icons.receipt_long_rounded, 'Billing'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Cp.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Row(
                children: [
                  const CircleAvatar(radius: 26, backgroundColor: Cp.primaryContainer, child: Text('RC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('CaterPro', style: TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('CaterPro Manager', style: TextStyle(color: Cp.onVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Cp.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                children: [
                  ...List.generate(items.length, (i) {
                    final selected = i == index;
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        selected: selected,
                        selectedTileColor: Cp.secondaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        leading: Icon(item.$1, color: selected ? const Color(0xff694000) : Cp.onVariant),
                        title: Text(item.$2, style: TextStyle(color: selected ? const Color(0xff694000) : Cp.onSurface, fontWeight: selected ? FontWeight.w900 : FontWeight.w700)),
                        onTap: () {
                          Navigator.pop(context);
                          onChanged(i);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(color: Cp.outlineVariant),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.restaurant_menu, color: Cp.onVariant),
                    title: const Text('Menu Master', style: TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(7);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    onChanged(5);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Event', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.subtitle, this.leading, this.actions = const [], this.avatar = true});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final canOpenDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final defaultLeading = canOpenDrawer
        ? Builder(
            builder: (context) => IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Cp.primary),
            ),
          )
        : (avatar ? const CircleAvatar(radius: 20, backgroundColor: Cp.primaryContainer, child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))) : const SizedBox.shrink());
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Cp.surface,
        child: Row(
          children: [
            leading ?? defaultLeading,
            if (leading != null || avatar || canOpenDrawer) const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cp.primary, fontSize: 22, height: 1.1, fontWeight: FontWeight.w800)),
                  if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Cp.onVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class CpCard extends StatelessWidget {
  const CpCard({super.key, required this.child, this.color = Cp.card, this.padding = const EdgeInsets.all(16), this.borderColor, this.onTap});

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Cp.outlineVariant.withValues(alpha: .35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
    return onTap == null ? card : InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: card);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Cp.surfaceHigh, this.textColor = Cp.onVariant, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

void showCpSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cp.primaryContainer,
    ),
  );
}

enum EventScreenAction {
  assignEmployees,
  downloadQuotation,
  downloadInvoice,
  currentDayMenu,
  allDaysMenu,
  shareMenu,
  deleteEvent,
  deleteDate,
  deleteMenu,
}

class EventActionMenuItem {
  const EventActionMenuItem(this.value, this.label, this.icon, {this.destructive = false});
  final EventScreenAction value;
  final String label;
  final IconData icon;
  final bool destructive;
}

const eventScreenActions = [
  EventActionMenuItem(EventScreenAction.assignEmployees, 'Assign Employees', Icons.group_add),
  EventActionMenuItem(EventScreenAction.downloadQuotation, 'Download Quotation', Icons.request_quote),
  EventActionMenuItem(EventScreenAction.downloadInvoice, 'Download Invoice', Icons.receipt_long),
  EventActionMenuItem(EventScreenAction.currentDayMenu, 'Current Day Menu', Icons.today),
  EventActionMenuItem(EventScreenAction.allDaysMenu, 'All Days Menu', Icons.date_range),
  EventActionMenuItem(EventScreenAction.shareMenu, 'Share Menu', Icons.share),
  EventActionMenuItem(EventScreenAction.deleteEvent, 'Delete Event', Icons.delete_forever, destructive: true),
  EventActionMenuItem(EventScreenAction.deleteDate, 'Delete Date', Icons.event_busy, destructive: true),
  EventActionMenuItem(EventScreenAction.deleteMenu, 'Delete Menu', Icons.no_meals, destructive: true),
];

Future<bool> confirmEventAction(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: Cp.error, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.topBar, required this.children, this.bottomPadding = 24});

  final Widget topBar;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        topBar,
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: children,
          ),
        ),
      ],
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.api, required this.events, required this.loading, required this.loadError, required this.openCreate, required this.openDetails, required this.refresh});
  final ApiService api;
  final List<AppEvent> events;
  final bool loading;
  final String? loadError;
  final VoidCallback openCreate;
  final ValueChanged<AppEvent> openDetails;
  final VoidCallback refresh;

  bool upcomingDate(AppEventDate date) {
    final parsed = parseIsoDate(date.date);
    if (parsed == null) return false;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = tomorrow.add(const Duration(days: 2));
    return !parsed.isBefore(tomorrow) && !parsed.isAfter(end);
  }

  List<AppEventDate> upcomingDatesFor(AppEvent event) => event.dates.where(upcomingDate).toList()..sort((a, b) => a.date.compareTo(b.date));

  bool hasMenuContent(AppEventDate date) => date.menuSlots.any((slot) => slot.enabled && slot.menuItemIds.isNotEmpty);

  List<AppEventDate> upcomingMenuDatesFor(AppEvent event) => upcomingDatesFor(event).where(hasMenuContent).toList();

  Future<void> downloadUpcomingMenus(BuildContext context) async {
    try {
      final error = await api.upcomingMenusError(days: 3);
      if (!context.mounted) return;
      if (error != null) {
        showCpSnack(context, error);
        return;
      }
      final uri = await api.upcomingMenusUri(days: 3);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (context.mounted) showCpSnack(context, launched ? 'Upcoming menus download started' : 'Unable to start menu download');
    } catch (error) {
      if (context.mounted) showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDates = events.fold<int>(0, (sum, event) => sum + event.dates.length);
    final totalSlots = events.fold<int>(0, (sum, event) => sum + event.dates.fold<int>(0, (dateSum, date) => dateSum + date.menuSlots.length));
    final paidTotal = events.fold<int>(0, (sum, event) => sum + eventPaid(event));
    final upcomingEvents = events.where((event) => upcomingDatesFor(event).isNotEmpty).toList();
    final upcomingMenuEvents = events.where((event) => upcomingMenuDatesFor(event).isNotEmpty).toList();
    return ScreenFrame(
      topBar: TopBar(
        title: 'CaterPro',
        subtitle: 'Manage your events',
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh_rounded, color: Cp.primary))],
      ),
      children: [
        if (loadError != null) ...[
          CpCard(color: Cp.errorContainer, child: Text(loadError!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: constraints.maxWidth > 720 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth > 720 ? 2.7 : 2.35,
            children: [
              MetricCard(label: 'Events', value: '${events.length}', note: loading ? 'Loading...' : 'Created', icon: Icons.calendar_month, color: Cp.card, valueColor: Cp.primary),
              MetricCard(label: 'Dates', value: '$totalDates', note: 'Event dates', icon: Icons.today, color: Cp.primaryFixed.withValues(alpha: .5), valueColor: Cp.primary),
              MetricCard(label: 'Menus', value: '$totalSlots', note: 'Menu slots', icon: Icons.restaurant_menu, color: Cp.secondaryFixed, valueColor: Cp.secondary),
              MetricCard(label: 'Payments', value: money(paidTotal), note: 'Collected', icon: Icons.payments, color: Cp.tertiaryFixed.withValues(alpha: .4), valueColor: Cp.tertiary),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Text('Upcoming Events', style: TextStyle(fontSize: 22, color: Cp.primary, fontWeight: FontWeight.w700))),
            IconButton(
              onPressed: upcomingMenuEvents.isEmpty ? null : () => downloadUpcomingMenus(context),
              icon: Icon(Icons.restaurant_menu, color: upcomingMenuEvents.isEmpty ? Cp.outline : Cp.primary),
              tooltip: upcomingMenuEvents.isEmpty ? 'No upcoming menus to download' : 'Download upcoming menus',
            ),
            Pill('${upcomingEvents.length} Upcoming', color: Cp.primary.withValues(alpha: .1), textColor: Cp.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (upcomingEvents.isEmpty)
          EmptyStateCard(title: 'No upcoming events', message: 'Events from tomorrow and the next 2 days will appear here.', actionLabel: events.isEmpty ? 'Create Event' : null, onAction: events.isEmpty ? openCreate : null)
        else
          ...upcomingEvents.map((event) {
            final dates = upcomingDatesFor(event);
            final pax = dates.fold<int>(0, (sum, date) => sum + date.menuSlots.fold<int>(0, (slotSum, slot) => slotSum + slot.pax));
            return EventMiniCard(title: event.name, client: event.mobile, time: dates.map((date) => readableDateLabel(date.date)).join(', '), pax: '$pax pax', showDraft: eventIsIncomplete(event), onTap: () => openDetails(event));
          }),
      ],
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.title, required this.message, this.actionLabel, this.onAction});
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => CpCard(
        color: Cp.surfaceLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.inbox_outlined, color: Cp.outline, size: 36),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onAction, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: const Icon(Icons.add), label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ]),
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.note, required this.icon, required this.color, required this.valueColor});
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return CpCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: valueColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: valueColor, size: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cp.onVariant, fontSize: 11, fontWeight: FontWeight.w800)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: valueColor, fontWeight: FontWeight.w900)),
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: valueColor, fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    final heights = [.40, .55, .45, .70, .85, 1.0];
    return CpCard(
      child: SizedBox(
        height: 160,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(heights.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FractionallySizedBox(
                        heightFactor: heights[i],
                        alignment: Alignment.bottomCenter,
                        child: Container(decoration: BoxDecoration(color: i == 5 ? Cp.primaryContainer : Cp.primaryFixed.withValues(alpha: .65), borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'].map((m) => Text(m, style: const TextStyle(fontSize: 10, color: Cp.onVariant, fontWeight: FontWeight.w600))).toList()),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 22, color: Cp.primary, fontWeight: FontWeight.w700))),
        if (trailing != null) Text(trailing!, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)),
        if (trailing != null) const Icon(Icons.chevron_right, color: Cp.primary, size: 18),
      ],
    );
  }
}

class EventMiniCard extends StatelessWidget {
  const EventMiniCard({super.key, required this.title, required this.client, required this.time, required this.pax, required this.showDraft, this.onTap});
  final String title;
  final String client;
  final String time;
  final String pax;
  final bool showDraft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text(client, style: const TextStyle(color: Cp.onVariant))])),
              if (showDraft) const Pill('DRAFT', color: Cp.secondaryFixed, textColor: Color(0xff663e00)),
            ]),
            const SizedBox(height: 12),
            Row(children: [const Icon(Icons.schedule, size: 18, color: Cp.onVariant), Text(' $time   ', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w600)), const Icon(Icons.group, size: 18, color: Cp.onVariant), Text(' $pax', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w600))]),
          ],
        ),
      ),
    );
  }
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.events, required this.loading, required this.loadError, required this.openDetails, required this.openCreate, required this.refresh});
  final List<AppEvent> events;
  final bool loading;
  final String? loadError;
  final ValueChanged<AppEvent> openDetails;
  final VoidCallback openCreate;
  final VoidCallback refresh;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final searchController = TextEditingController();
  String query = '';
  String? clientFilter;
  String? dateFilter;
  bool showPastEvents = true;
  bool showOverduePayments = false;
  String paymentFilter = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<String> get clientOptions {
    final clients = widget.events.map((event) => event.primaryClient.isEmpty ? event.name : event.primaryClient).where((client) => client.trim().isNotEmpty).toSet().toList()..sort();
    return clients;
  }

  List<AppEvent> get filteredEvents {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return widget.events.where((event) {
      final client = event.primaryClient.isEmpty ? event.name : event.primaryClient;
      final haystack = '${event.name} $client ${event.mobile}'.toLowerCase();
      if (query.isNotEmpty && !haystack.contains(query.toLowerCase())) return false;
      if (clientFilter != null && client != clientFilter) return false;
      if (dateFilter != null && !event.dates.any((date) => date.date == dateFilter)) return false;
      if (!showPastEvents && event.dates.any((date) => _parseDate(date.date)?.isBefore(todayOnly) ?? false)) return false;
      final balance = eventBalance(event);
      if (paymentFilter == 'Paid' && balance != 0) return false;
      if (paymentFilter == 'Unpaid' && balance == 0) return false;
      if (showOverduePayments && !(balance > 0 && event.dates.any((date) => _parseDate(date.date)?.isBefore(todayOnly) ?? false))) return false;
      return true;
    }).toList();
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> chooseClient() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            const Text('Filter Client', style: TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.all_inclusive, color: Cp.primary), title: const Text('All Clients'), onTap: () => Navigator.pop(context, null)),
            ...clientOptions.map((client) => ListTile(leading: Icon(client == clientFilter ? Icons.check_circle : Icons.person, color: Cp.primary), title: Text(client), onTap: () => Navigator.pop(context, client))),
          ]),
        ),
      ),
    );
    if (mounted) setState(() => clientFilter = selected);
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: DateTime.now());
    if (picked == null) return;
    setState(() => dateFilter = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  void clearFilters() {
    setState(() {
      clientFilter = null;
      dateFilter = null;
      showPastEvents = true;
      showOverduePayments = false;
      paymentFilter = 'All';
      query = '';
      searchController.clear();
    });
  }

  PopupMenuItem<String> filterMenuItem(String value, IconData icon, String label, {bool selected = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(selected ? Icons.check_circle : icon, color: selected ? Cp.tertiaryContainer : Cp.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = filteredEvents;
    return ScreenFrame(
      topBar: TopBar(title: 'Events', actions: [
        IconButton(onPressed: widget.refresh, icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: Cp.primary),
          tooltip: 'Filter events',
          onSelected: (value) {
            switch (value) {
              case 'client':
                chooseClient();
                break;
              case 'date':
                chooseDate();
                break;
              case 'past':
                setState(() => showPastEvents = !showPastEvents);
                break;
              case 'overdue':
                setState(() => showOverduePayments = !showOverduePayments);
                break;
              case 'paid':
                setState(() => paymentFilter = paymentFilter == 'Paid' ? 'All' : 'Paid');
                break;
              case 'unpaid':
                setState(() => paymentFilter = paymentFilter == 'Unpaid' ? 'All' : 'Unpaid');
                break;
              case 'clear':
                clearFilters();
                break;
            }
          },
          itemBuilder: (context) => [
            filterMenuItem('client', Icons.person_search, clientFilter == null ? 'Filter Client' : 'Client: $clientFilter', selected: clientFilter != null),
            filterMenuItem('date', Icons.event, dateFilter == null ? 'Filter Date' : 'Date: $dateFilter', selected: dateFilter != null),
            filterMenuItem('past', Icons.history, showPastEvents ? 'Hide Past Events' : 'Show Past Events', selected: !showPastEvents),
            filterMenuItem('overdue', Icons.warning_amber, 'Show Overdue Payments', selected: showOverduePayments),
            const PopupMenuDivider(),
            filterMenuItem('paid', Icons.check_circle, 'Payment Status: Paid', selected: paymentFilter == 'Paid'),
            filterMenuItem('unpaid', Icons.cancel, 'Payment Status: Unpaid', selected: paymentFilter == 'Unpaid'),
            const PopupMenuDivider(),
            filterMenuItem('clear', Icons.filter_alt_off, 'Clear Filters'),
          ],
        ),
        IconButton(onPressed: widget.openCreate, icon: const Icon(Icons.add)),
      ]),
      children: [
        TextField(
          controller: searchController,
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search by event or client name',
            prefixIcon: const Icon(Icons.search, color: Cp.outline),
            suffixIcon: query.isEmpty ? null : IconButton(onPressed: () => setState(() { query = ''; searchController.clear(); }), icon: const Icon(Icons.close)),
            filled: true,
            fillColor: Cp.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cp.outlineVariant)),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('${visible.length} shown', color: Cp.primary.withValues(alpha: .1), textColor: Cp.primary),
          if (clientFilter != null) Pill(clientFilter!, color: Cp.surfaceHigh, textColor: Cp.onVariant, icon: Icons.person),
          if (dateFilter != null) Pill(dateFilter!, color: Cp.surfaceHigh, textColor: Cp.onVariant, icon: Icons.event),
          if (paymentFilter != 'All') Pill(paymentFilter, color: Cp.surfaceHigh, textColor: Cp.onVariant, icon: Icons.payments),
          if (!showPastEvents || showOverduePayments || clientFilter != null || dateFilter != null || paymentFilter != 'All' || query.isNotEmpty)
            InkWell(onTap: clearFilters, child: const Pill('Clear', color: Cp.errorContainer, textColor: Cp.error, icon: Icons.close)),
        ]),
        const SizedBox(height: 16),
        if (widget.loadError != null) CpCard(color: Cp.errorContainer, child: Text(widget.loadError!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
        if (widget.loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (widget.events.isEmpty)
          EmptyStateCard(title: 'No events added', message: 'Use Create Event to add the first event from scratch.', actionLabel: 'Create Event', onAction: widget.openCreate)
        else if (visible.isEmpty)
          const EmptyStateCard(title: 'No matching events', message: 'Try changing the search or filter options.')
        else
          ...visible.map((event) {
            final meals = event.dates.expand((date) => date.menuSlots.map((slot) => slot.type)).toSet().toList();
            final dateText = event.dates.isEmpty ? 'No dates' : event.dates.map((date) => date.date).join(', ');
            final balance = eventBalance(event);
            return EventListCard(title: event.name, client: event.primaryClient.isEmpty ? event.name : event.primaryClient, phone: event.mobile, dates: dateText, amount: money(eventTotal(event)), balance: balance == 0 ? 'Paid' : '${money(balance)} due', status: balance == 0 ? 'PAID' : 'UNPAID', meals: meals, onTap: () => widget.openDetails(event));
          }),
      ],
    );
  }
}

class ChipRow extends StatefulWidget {
  const ChipRow(this.labels, {super.key});
  final List<String> labels;

  @override
  State<ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<ChipRow> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(widget.labels.length, (i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() => selectedIndex = i);
                showCpSnack(context, '${widget.labels[i]} selected');
              },
              child: Pill(widget.labels[i], color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
            ),
          );
        }),
      ),
    );
  }
}

class EventListCard extends StatelessWidget {
  const EventListCard({super.key, required this.title, required this.client, required this.phone, required this.dates, required this.amount, required this.balance, required this.status, required this.meals, this.onTap});
  final String title, client, phone, dates, amount, balance, status;
  final List<String> meals;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final pending = status != 'PAID';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        color: pending ? const Color(0xffffebeb) : Cp.card,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, color: Cp.primary, fontWeight: FontWeight.w800)), Row(children: [const Icon(Icons.person, size: 16, color: Cp.onVariant), Flexible(child: Text(' $client • $phone', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w600)))])])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Pill(status, color: pending ? Cp.secondaryContainer : Cp.tertiaryFixed, textColor: pending ? Color(0xff694000) : Color(0xff00210c)), const SizedBox(height: 6), Text(amount, style: const TextStyle(color: Cp.primaryContainer, fontWeight: FontWeight.w900)), Text(balance, style: TextStyle(color: balance.startsWith('Paid') ? Cp.tertiary : Cp.error, fontWeight: FontWeight.w800, fontSize: 12))]),
            ]),
            const SizedBox(height: 14),
            Row(children: [const Icon(Icons.calendar_today, size: 18, color: Cp.onVariant), Text(' $dates', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: meals.map((m) => Pill(m, color: Cp.surfaceHigh, textColor: Cp.onSurface)).toList()),
          ],
        ),
      ),
    );
  }
}

class ClientSummary {
  const ClientSummary({required this.client, required this.events, required this.invoices});
  final AppClient client;
  final List<AppEvent> events;
  final List<ManualInvoice> invoices;

  int get revenue => events.fold(0, (sum, event) => sum + eventTotal(event)) + invoices.fold(0, (sum, invoice) => sum + invoice.total);
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.clients, required this.events, required this.manualInvoices, required this.onSaveClient, required this.onDeleteClient, required this.openEvent});
  final List<AppClient> clients;
  final List<AppEvent> events;
  final List<ManualInvoice> manualInvoices;
  final Future<void> Function(AppClient client) onSaveClient;
  final Future<void> Function(AppClient client) onDeleteClient;
  final ValueChanged<AppEvent> openEvent;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ClientSummary> get summaries {
    final map = <String, AppClient>{};
    void put(AppClient client) {
      final mobile = normalizeMobileText(client.mobile);
      if (mobile.isEmpty) return;
      final existing = map[mobile];
      map[mobile] = AppClient(
        id: existing?.id.isNotEmpty == true ? existing!.id : client.id,
        name: client.name.isNotEmpty ? client.name : existing?.name ?? mobile,
        mobile: mobile,
        city: client.city.isNotEmpty ? client.city : existing?.city ?? '',
        notes: client.notes.isNotEmpty ? client.notes : existing?.notes ?? '',
      );
    }

    for (final client in widget.clients) {
      put(client);
    }
    for (final event in widget.events) {
      put(AppClient(id: '', name: event.primaryClient.isEmpty ? event.name : event.primaryClient, mobile: event.mobile, city: event.venue));
    }
    for (final invoice in widget.manualInvoices) {
      put(AppClient(id: '', name: invoice.clientName, mobile: invoice.mobile, city: invoice.venue));
    }

    final result = map.values.map((client) {
      final mobile = normalizeMobileText(client.mobile);
      return ClientSummary(
        client: client,
        events: widget.events.where((event) => normalizeMobileText(event.mobile) == mobile).toList(),
        invoices: widget.manualInvoices.where((invoice) => normalizeMobileText(invoice.mobile) == mobile).toList(),
      );
    }).toList()
      ..sort((a, b) => a.client.name.toLowerCase().compareTo(b.client.name.toLowerCase()));
    if (query.isEmpty) return result;
    final q = query.toLowerCase();
    return result.where((summary) => [summary.client.name, summary.client.mobile, summary.client.city].any((value) => value.toLowerCase().contains(q))).toList();
  }

  Future<void> editClient(AppClient client) async {
    await showClientEditor(context, client: client, onSave: widget.onSaveClient);
    if (mounted) setState(() {});
  }

  Future<void> deleteClient(AppClient client) async {
    if (client.id.isEmpty) {
      showCpSnack(context, 'This client is coming from event/bill data. Edit or delete the linked record first.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Delete ${client.name} from the client master? Events and invoices will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.onDeleteClient(client);
    if (mounted) showCpSnack(context, 'Client deleted');
  }

  void showEvents(ClientSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Events - ${summary.client.name}', style: const TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (summary.events.isEmpty) const EmptyStateCard(title: 'No events', message: 'No events found for this client.'),
          ...summary.events.map((event) => ListTile(
                leading: const Icon(Icons.event, color: Cp.primary),
                title: Text(event.name),
                subtitle: Text(event.dates.map((date) => date.date).join(', ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  widget.openEvent(event);
                },
              )),
        ],
      ),
    );
  }

  void showBills(ClientSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bills - ${summary.client.name}', style: const TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (summary.events.where((event) => event.payments.isNotEmpty).isEmpty && summary.invoices.isEmpty) const EmptyStateCard(title: 'No bills', message: 'No invoices or payments found for this client.'),
          ...summary.invoices.map((invoice) => ListTile(leading: const Icon(Icons.receipt_long, color: Cp.primary), title: Text(invoice.eventName), subtitle: Text(invoice.invoiceNumber), trailing: Text(money(invoice.total)))),
          ...summary.events.expand((event) => event.payments.map((payment) => ListTile(leading: const Icon(Icons.payments, color: Cp.tertiaryContainer), title: Text(event.name), subtitle: Text(payment.date), trailing: Text(money(payment.amount))))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = summaries;
    return ScreenFrame(
      topBar: TopBar(title: 'CaterPro', actions: [IconButton(onPressed: () => showClientEditor(context, onSave: widget.onSaveClient), icon: const Icon(Icons.add, color: Cp.primary)), IconButton(onPressed: () => showCpSnack(context, 'Notifications opened'), icon: const Icon(Icons.notifications, color: Cp.primary))]),
      children: [
        TextField(
          controller: search,
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search clients by name, city, or phone...',
            prefixIcon: const Icon(Icons.search, color: Cp.outline),
            suffixIcon: query.isEmpty ? null : IconButton(onPressed: () => setState(() { query = ''; search.clear(); }), icon: const Icon(Icons.close)),
            filled: true,
            fillColor: Cp.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cp.outlineVariant)),
          ),
        ),
        const SizedBox(height: 22),
        Row(children: [const Expanded(child: Text('Clients', style: TextStyle(fontSize: 22, color: Cp.primary, fontWeight: FontWeight.w700))), Text('${visible.length} Total', style: const TextStyle(color: Cp.outline, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const EmptyStateCard(title: 'No clients yet', message: 'Clients will appear after you create events, bills, or client records.')
        else
          ...visible.map((summary) => ClientCard(
                summary: summary,
                onEvents: () => showEvents(summary),
                onBills: () => showBills(summary),
                onEdit: () => editClient(summary.client),
                onDelete: () => deleteClient(summary.client),
              )),
      ],
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, {super.key});
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Cp.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Cp.outlineVariant)),
      child: Row(children: [const Icon(Icons.search, color: Cp.outline), const SizedBox(width: 12), Expanded(child: Text(hint, style: const TextStyle(color: Cp.outline, fontSize: 15)))]),
    );
  }
}

class ClientCard extends StatefulWidget {
  const ClientCard({super.key, required this.summary, required this.onEvents, required this.onBills, required this.onEdit, required this.onDelete});
  final ClientSummary summary;
  final VoidCallback onEvents;
  final VoidCallback onBills;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<ClientCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final client = summary.client;
    final initials = client.name.trim().isEmpty ? 'C' : client.name.trim().split(RegExp(r'\s+')).take(2).map((part) => part[0].toUpperCase()).join();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 24, backgroundColor: Cp.primaryContainer, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(client.name.isEmpty ? client.mobile : client.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text(client.mobile, style: const TextStyle(fontSize: 12, color: Cp.outline, fontWeight: FontWeight.w600)), if (client.city.isNotEmpty) Text(client.city, style: const TextStyle(fontSize: 12, color: Cp.outline, fontWeight: FontWeight.w600))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(summary.revenue), style: const TextStyle(color: Cp.secondary, fontSize: 16, fontWeight: FontWeight.w900)),
              Text('${summary.events.length} events • ${summary.invoices.length} bills', style: const TextStyle(color: Cp.outline, fontSize: 12)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: expanded ? 'Hide client options' : 'Show client options',
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.more_horiz_rounded, color: Cp.primary),
              ),
            ]),
          ]),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: [
              const Divider(height: 24, color: Cp.outlineVariant),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(avatar: const Icon(Icons.event, size: 18), label: const Text('Events'), onPressed: widget.onEvents),
                ActionChip(avatar: const Icon(Icons.receipt_long, size: 18), label: const Text('Bills'), onPressed: widget.onBills),
                ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Call'), onPressed: () => launchUrl(Uri.parse('tel:${client.mobile}'))),
                ActionChip(avatar: const Icon(Icons.chat, size: 18), label: const Text('WhatsApp'), onPressed: () => launchUrl(Uri.parse('https://wa.me/91${client.mobile}'), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank')),
                ActionChip(avatar: const Icon(Icons.edit, size: 18), label: const Text('Edit'), onPressed: widget.onEdit),
                ActionChip(avatar: const Icon(Icons.delete, size: 18, color: Cp.error), label: const Text('Delete'), onPressed: widget.onDelete),
              ]),
            ]),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ]),
      ),
    );
  }
}

Future<void> showClientEditor(BuildContext context, {AppClient? client, required Future<void> Function(AppClient client) onSave}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: client?.name ?? '');
  final mobile = TextEditingController(text: client?.mobile ?? '');
  final city = TextEditingController(text: client?.city ?? '');
  final notes = TextEditingController(text: client?.notes ?? '');
  final address = TextEditingController(text: client?.address ?? '');
  final gst = TextEditingController(text: client?.gst ?? '');
  bool saving = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 58, height: 6, decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 18),
            Text(client == null ? 'Add Client' : 'Edit Client', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextFormField(controller: name, validator: (value) => requiredTextValidator(value, 'Client name'), decoration: InputDecoration(labelText: 'Client Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextFormField(controller: mobile, keyboardType: TextInputType.phone, inputFormatters: mobileInputFormatters, validator: mobileValidator, decoration: InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextFormField(controller: city, decoration: InputDecoration(labelText: 'City / Area', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextFormField(controller: address, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: 'Client Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextFormField(controller: gst, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'GST', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextFormField(controller: notes, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final clean = normalizeMobileText(mobile.text);
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setSheetState(() => saving = true);
                        try {
                          await onSave(AppClient(id: client?.id ?? '', name: name.text.trim(), mobile: clean, city: city.text.trim(), notes: notes.text.trim(), address: address.text.trim(), gst: gst.text.trim()));
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
                        } finally {
                          setSheetState(() => saving = false);
                        }
                      },
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save Client', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            ]),
          ),
        ),
      ),
    ),
  );
  name.dispose();
  mobile.dispose();
  city.dispose();
  notes.dispose();
  address.dispose();
  gst.dispose();
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, required this.events, required this.manualInvoices, required this.api, required this.onSaveManualInvoice, required this.onAddManualInvoice});
  final List<AppEvent> events;
  final List<ManualInvoice> manualInvoices;
  final ApiService api;
  final Future<void> Function(ManualInvoice invoice) onSaveManualInvoice;
  final VoidCallback onAddManualInvoice;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  int selectedTab = 0;

  List<AppEvent> get quotationEvents => widget.events.where((event) => event.payments.isEmpty).toList();
  List<({AppEvent event, AppPayment payment})> get invoicePayments => [
        for (final event in widget.events)
          for (final payment in event.payments) (event: event, payment: payment),
      ];

  Future<void> downloadDocument(BuildContext context, AppEvent event, String type) async {
    final uri = await widget.api.documentUri(event.id, type);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    showCpSnack(context, launched ? '${type == 'invoice' ? 'Invoice' : 'Quotation'} download started' : 'Unable to start download');
  }

  void openDocumentDetails(AppEvent event, String type, {AppPayment? payment}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BillingDocumentDetailsScreen(event: event, payment: payment, type: type, api: widget.api),
    ));
  }

  Future<void> openAddInvoice() async {
    widget.onAddManualInvoice();
  }

  Future<void> downloadManualInvoice(BuildContext context, ManualInvoice invoice) async {
    final uri = await widget.api.manualInvoicePdfUri(invoice.id);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    showCpSnack(context, launched ? 'Invoice download started' : 'Unable to start download');
  }

  void openManualInvoiceDetails(ManualInvoice invoice) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManualInvoiceDetailsScreen(invoice: invoice, api: widget.api)));
  }

  Widget tabChip(int index, String label, int count) {
    final selected = selectedTab == index;
    return ChoiceChip(
      selected: selected,
      selectedColor: Cp.primaryContainer,
      labelStyle: TextStyle(color: selected ? Colors.white : Cp.onVariant, fontWeight: FontWeight.w900),
      label: Text('$label ($count)'),
      onSelected: (_) => setState(() => selectedTab = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuotationValue = quotationEvents.fold<int>(0, (sum, event) => sum + eventTotal(event));
    final totalInvoiceValue = invoicePayments.fold<int>(0, (sum, item) => sum + item.payment.amount) + widget.manualInvoices.fold<int>(0, (sum, invoice) => sum + invoice.total);
    return ScreenFrame(
      topBar: TopBar(title: 'Billing', subtitle: 'Quotations and invoices', actions: [IconButton(onPressed: openAddInvoice, icon: const Icon(Icons.add, color: Cp.primary), tooltip: 'Add invoice')]),
      children: [
        Row(children: [
          Expanded(child: BillingSummaryCell(label: 'Quotation Value', value: money(totalQuotationValue), icon: Icons.request_quote, color: Cp.primary)),
          const SizedBox(width: 10),
          Expanded(child: BillingSummaryCell(label: 'Invoice Payments', value: money(totalInvoiceValue), icon: Icons.receipt_long, color: Cp.tertiaryContainer)),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [tabChip(0, 'Quotations', quotationEvents.length), const SizedBox(width: 8), tabChip(1, 'Invoices', invoicePayments.length + widget.manualInvoices.length)])),
        const SizedBox(height: 16),
        if (selectedTab == 0) ...[
          if (quotationEvents.isEmpty)
            const EmptyStateCard(title: 'No quotations pending', message: 'Events move here only until the first payment is recorded.')
          else
            ...quotationEvents.map((event) => BillingDocumentCard(
                  title: event.name,
                  subtitle: '${event.primaryClient.isEmpty ? event.mobile : event.primaryClient} • ${event.mobile}',
                  code: 'QUOTE-${event.id.toUpperCase()}',
                  amountLabel: 'Event Total',
                  amount: money(eventTotal(event)),
                  dateLabel: event.dates.isEmpty ? 'No dates' : event.dates.map((date) => date.date).join(', '),
                  status: 'Quotation',
                  statusColor: Cp.primary,
                  icon: Icons.request_quote,
                  onDownload: () => downloadDocument(context, event, 'quotation'),
                  onTap: () => openDocumentDetails(event, 'quotation'),
                )),
        ] else ...[
          if (invoicePayments.isEmpty && widget.manualInvoices.isEmpty)
            const EmptyStateCard(title: 'No invoices yet', message: 'Invoices appear here after any payment is recorded for an event.')
          else
            ...[
            ...widget.manualInvoices.map((invoice) => BillingDocumentCard(
                  title: invoice.eventName,
                  subtitle: '${invoice.clientName} • ${invoice.mobile}',
                  code: invoice.invoiceNumber.isEmpty ? 'INV-${invoice.id.toUpperCase()}' : invoice.invoiceNumber,
                  amountLabel: invoice.pending == 0 ? 'Total' : 'Pending',
                  amount: money(invoice.pending == 0 ? invoice.total : invoice.pending),
                  dateLabel: invoice.invoiceDate,
                  status: invoice.pending == 0 ? 'Settled' : 'Manual',
                  statusColor: invoice.pending == 0 ? Cp.tertiaryContainer : Cp.primary,
                  icon: Icons.receipt,
                  onDownload: () => downloadManualInvoice(context, invoice),
                  onTap: () => openManualInvoiceDetails(invoice),
                )),
            ...invoicePayments.map((item) => BillingDocumentCard(
                  title: item.event.name,
                  subtitle: '${item.event.primaryClient.isEmpty ? item.event.mobile : item.event.primaryClient} • ${item.payment.mode}${item.payment.reference.isEmpty ? '' : ' • ${item.payment.reference}'}',
                  code: 'INV-${item.payment.id.toUpperCase()}',
                  amountLabel: 'Payment Amount',
                  amount: money(item.payment.amount),
                  dateLabel: item.payment.date,
                  status: item.payment.settled ? 'Settled' : 'Paid',
                  statusColor: item.payment.settled ? Cp.tertiaryContainer : Cp.tertiary,
                  icon: Icons.receipt_long,
                  onDownload: () => downloadDocument(context, item.event, 'invoice'),
                  onTap: () => openDocumentDetails(item.event, 'invoice', payment: item.payment),
                )),
            ],
        ],
      ],
    );
  }
}

class ManualInvoiceLineController {
  ManualInvoiceLineController({String title = '', String quantity = '1', String rate = ''})
      : title = TextEditingController(text: title),
        quantity = TextEditingController(text: quantity),
        rate = TextEditingController(text: rate);
  final TextEditingController title;
  final TextEditingController quantity;
  final TextEditingController rate;

  void dispose() {
    title.dispose();
    quantity.dispose();
    rate.dispose();
  }
}

class ClientLookupField extends StatefulWidget {
  const ClientLookupField({super.key, required this.label, required this.controller, required this.clients, required this.onSelected, this.validator, this.keyboardType, this.inputFormatters});
  final String label;
  final TextEditingController controller;
  final List<AppClient> clients;
  final ValueChanged<AppClient> onSelected;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<ClientLookupField> createState() => _ClientLookupFieldState();
}

class _ClientLookupFieldState extends State<ClientLookupField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  List<AppClient> get matches {
    final query = widget.controller.text.trim().toLowerCase();
    if (query.isEmpty || !focusNode.hasFocus) return [];
    final queryDigits = normalizeMobileText(query);
    return widget.clients.where((client) {
      final mobile = normalizeMobileText(client.mobile);
      return client.name.toLowerCase().contains(query) || (queryDigits.isNotEmpty && mobile.contains(queryDigits)) || client.gst.toLowerCase().contains(query);
    }).take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = matches;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: widget.controller,
        focusNode: focusNode,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
        decoration: InputDecoration(labelText: widget.label, prefixIcon: Icon(widget.keyboardType == TextInputType.phone ? Icons.phone_android : Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      if (results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: Cp.surface, border: Border.all(color: Cp.outlineVariant), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12)]),
          child: Column(
            children: results.map((client) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_search, color: Cp.primary),
                title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text([normalizeMobileText(client.mobile), client.address.isNotEmpty ? client.address : client.city, client.gst].where((item) => item.trim().isNotEmpty).join(' • ')),
                onTap: () {
                  widget.onSelected(client);
                  focusNode.unfocus();
                },
              );
            }).toList(),
          ),
        ),
    ]);
  }
}

class ManualInvoiceFormScreen extends StatefulWidget {
  const ManualInvoiceFormScreen({super.key, required this.clients, required this.onSave});
  final List<AppClient> clients;
  final Future<void> Function(ManualInvoice invoice) onSave;

  @override
  State<ManualInvoiceFormScreen> createState() => _ManualInvoiceFormScreenState();
}

class _ManualInvoiceFormScreenState extends State<ManualInvoiceFormScreen> {
  final formKey = GlobalKey<FormState>();
  final clientName = TextEditingController();
  final mobile = TextEditingController();
  final clientAddress = TextEditingController();
  final clientGst = TextEditingController();
  final eventName = TextEditingController();
  final venue = TextEditingController();
  final eventDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final invoiceDate = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final advance = TextEditingController(text: '0');
  final settlement = TextEditingController(text: '0');
  final notes = TextEditingController();
  final items = <ManualInvoiceLineController>[ManualInvoiceLineController(title: 'Catering service')];
  bool saving = false;

  @override
  void dispose() {
    clientName.dispose();
    mobile.dispose();
    clientAddress.dispose();
    clientGst.dispose();
    eventName.dispose();
    venue.dispose();
    eventDate.dispose();
    invoiceDate.dispose();
    advance.dispose();
    settlement.dispose();
    notes.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  int number(TextEditingController controller) => int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
  String cleanMobile() => normalizeMobileText(mobile.text);
  int lineAmount(ManualInvoiceLineController item) => number(item.quantity) * number(item.rate);

  int get subtotal => items.fold(0, (sum, item) {
        return sum + lineAmount(item);
      });
  int get pending => (subtotal - number(advance) - number(settlement)).clamp(0, subtotal);

  Future<void> pickDate(TextEditingController controller) async {
    final initial = parseIsoDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => controller.text = picked.toIso8601String().substring(0, 10));
  }

  void addItem() => setState(() => items.add(ManualInvoiceLineController()));

  void removeItem(int index) {
    if (items.length == 1) return;
    final removed = items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void selectClient(AppClient client) {
    setState(() {
      clientName.text = client.name;
      mobile.text = normalizeMobileText(client.mobile);
      clientAddress.text = client.address.isNotEmpty ? client.address : client.city;
      clientGst.text = client.gst;
    });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final lines = <ManualInvoiceItem>[];
    for (final item in items) {
      final title = item.title.text.trim();
      final qty = number(item.quantity);
      final rate = number(item.rate);
      final amount = qty * rate;
      if (title.isNotEmpty && amount > 0) {
        lines.add(ManualInvoiceItem(id: '', title: title, quantity: qty, rate: rate, amount: amount));
      }
    }
    if (lines.isEmpty) {
      showCpSnack(context, 'Add at least one invoice item with amount');
      return;
    }
    final adv = number(advance);
    final settle = number(settlement);
    if (adv + settle > subtotal) {
      showCpSnack(context, 'Advance and settlement cannot exceed total');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(ManualInvoice(
        id: '',
        clientName: clientName.text.trim(),
        mobile: cleanMobile(),
        clientAddress: clientAddress.text.trim(),
        clientGst: clientGst.text.trim(),
        eventName: eventName.text.trim(),
        venue: venue.text.trim(),
        eventDate: eventDate.text.trim(),
        invoiceDate: invoiceDate.text.trim(),
        invoiceNumber: '',
        notes: notes.text.trim(),
        items: lines,
        subtotal: subtotal,
        total: subtotal,
        advance: adv,
        settlement: settle,
        pending: pending,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showCpSnack(context, 'Invoice saved');
    } catch (e) {
      if (mounted) showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration fieldDecoration(String label, {IconData? icon}) => InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cp.background,
      body: Form(
        key: formKey,
        child: ScreenFrame(
          topBar: TopBar(title: 'Add Invoice', avatar: false, leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Cp.primary))),
          bottomPadding: 110,
          children: [
            CpCard(
              child: Column(children: [
                ClientLookupField(
                  label: 'Client Name',
                  controller: clientName,
                  clients: widget.clients,
                  onSelected: selectClient,
                  validator: (value) => requiredTextValidator(value, 'Client name'),
                ),
                const SizedBox(height: 12),
                ClientLookupField(
                  label: 'Mobile Number',
                  controller: mobile,
                  clients: widget.clients,
                  onSelected: selectClient,
                  keyboardType: TextInputType.phone,
                  inputFormatters: mobileInputFormatters,
                  validator: mobileValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: clientAddress, minLines: 2, maxLines: 3, decoration: fieldDecoration('Client Address', icon: Icons.home_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: clientGst, textCapitalization: TextCapitalization.characters, decoration: fieldDecoration('Client GST', icon: Icons.badge_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: eventName, decoration: fieldDecoration('Event Name', icon: Icons.celebration), validator: (value) => requiredTextValidator(value, 'Event name')),
                const SizedBox(height: 12),
                TextFormField(controller: venue, decoration: fieldDecoration('Venue', icon: Icons.place)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: eventDate, readOnly: true, onTap: () => pickDate(eventDate), decoration: fieldDecoration('Event Date', icon: Icons.event), validator: (value) => isoDateValidator(value, label: 'Event date'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: invoiceDate, readOnly: true, onTap: () => pickDate(invoiceDate), decoration: fieldDecoration('Invoice Date', icon: Icons.receipt), validator: (value) => isoDateValidator(value, label: 'Invoice date'))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            CpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Expanded(child: Text('Invoice Items', style: TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900))), IconButton(onPressed: addItem, icon: const Icon(Icons.add_circle, color: Cp.primary))]),
                const SizedBox(height: 8),
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth > 820;
                      final fields = [
                        Expanded(flex: 4, child: TextFormField(controller: item.title, decoration: fieldDecoration('Item Title'), validator: (value) => requiredTextValidator(value, 'Item title'))),
                        const SizedBox(width: 8),
                        SizedBox(width: wide ? 110 : null, child: TextFormField(controller: item.quantity, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {}), decoration: fieldDecoration('Qty'), validator: (value) => positiveMoneyValidator(value, 'Qty', allowZero: false))),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: TextFormField(controller: item.rate, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {}), decoration: fieldDecoration('Rate'), validator: (value) => positiveMoneyValidator(value, 'Rate', allowZero: false))),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: InputDecorator(decoration: fieldDecoration('Amount'), child: Text(money(lineAmount(item)), style: const TextStyle(fontWeight: FontWeight.w900)))),
                        IconButton(onPressed: () => removeItem(index), icon: const Icon(Icons.delete, color: Cp.error)),
                      ];
                      if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields);
                      return Column(children: [
                        Row(children: [fields[0], fields.last]),
                        const SizedBox(height: 10),
                        Row(children: fields.sublist(2, 7)),
                      ]);
                    }),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 12),
            CpCard(
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextFormField(controller: advance, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: fieldDecoration('Advance Paid', icon: Icons.payments), validator: (value) => positiveMoneyValidator(value, 'Advance paid', allowZero: true))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: settlement, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: fieldDecoration('Settlement / Discount', icon: Icons.price_check), validator: (value) => positiveMoneyValidator(value, 'Settlement', allowZero: true))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: notes, minLines: 2, maxLines: 4, decoration: fieldDecoration('Notes')),
                const Divider(height: 24),
                AmountLine('Grand Total', money(subtotal), strong: true),
                AmountLine('Advance', money(number(advance)), color: Cp.tertiaryContainer),
                AmountLine('Settlement', money(number(settlement)), color: Cp.tertiaryContainer),
                AmountLine('Pending', money(pending), color: pending == 0 ? Cp.tertiaryContainer : Cp.error, strong: true),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Cp.surface,
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: Cp.primary), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save Invoice', style: const TextStyle(fontWeight: FontWeight.w900))),
          ),
        ),
      ),
    );
  }
}

class ManualInvoiceDetailsScreen extends StatelessWidget {
  const ManualInvoiceDetailsScreen({super.key, required this.invoice, required this.api});
  final ManualInvoice invoice;
  final ApiService api;

  Future<void> download(BuildContext context) async {
    final uri = await api.manualInvoicePdfUri(invoice.id);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (context.mounted) showCpSnack(context, launched ? 'Invoice download started' : 'Unable to start download');
  }

  Future<void> requestPayment() async {
    final text = 'Hello ${invoice.clientName}, pending payment for ${invoice.eventName} is ${money(invoice.pending)}. Please complete the payment. - CaterPro';
    await launchUrl(Uri.parse('https://wa.me/91${invoice.mobile}?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cp.background,
      body: ScreenFrame(
        topBar: TopBar(title: 'Invoice Details', avatar: false, leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        bottomPadding: 96,
        children: [
          CpCard(
            color: const Color(0xfffff7ff),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: CircleAvatar(radius: 30, backgroundColor: invoice.pending == 0 ? Cp.tertiaryFixed : Cp.primaryFixed, child: Icon(invoice.pending == 0 ? Icons.check : Icons.receipt_long, color: invoice.pending == 0 ? Cp.tertiaryContainer : Cp.primary, size: 34))),
              const SizedBox(height: 12),
              Center(child: Text(invoice.pending == 0 ? 'Invoice settled' : 'Pending ${money(invoice.pending)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              const Divider(height: 28),
              DetailNavTile(iconText: invoice.clientName.isEmpty ? 'C' : invoice.clientName[0].toUpperCase(), label: 'Client Name', value: '${invoice.clientName} • ${invoice.mobile}'),
              if (invoice.clientAddress.isNotEmpty) SmallInfoBlock(label: 'Client Address', value: invoice.clientAddress),
              if (invoice.clientGst.isNotEmpty) SmallInfoBlock(label: 'Client GST', value: invoice.clientGst),
              DetailNavTile(iconText: invoice.eventName.isEmpty ? 'E' : invoice.eventName[0].toUpperCase(), label: 'Event Name', value: invoice.eventName),
              SmallInfoBlock(label: 'Invoice#', value: invoice.invoiceNumber.isEmpty ? invoice.id.toUpperCase() : invoice.invoiceNumber),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: SmallInfoBlock(label: 'Event Date', value: invoice.eventDate)), Expanded(child: SmallInfoBlock(label: 'Invoice Date', value: invoice.invoiceDate))]),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items', style: TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...invoice.items.map((item) => AmountLine(item.title, money(item.amount))),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            child: Column(children: [
              AmountLine('Grand Total', money(invoice.total), strong: true),
              AmountLine('Advance / Paid', money(invoice.advance), color: Cp.tertiaryContainer),
              AmountLine('Settlement', money(invoice.settlement), color: Cp.tertiaryContainer),
              const Divider(height: 18),
              AmountLine('Pending', money(invoice.pending), color: invoice.pending == 0 ? Cp.tertiaryContainer : Cp.error, strong: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Cp.surface,
          child: Row(children: [
            Expanded(child: FilledButton(onPressed: invoice.pending == 0 ? null : requestPayment, style: FilledButton.styleFrom(backgroundColor: Cp.secondaryContainer, foregroundColor: const Color(0xff694000)), child: const Text('Request Payment', style: TextStyle(fontWeight: FontWeight.w900)))),
            const SizedBox(width: 10),
            IconButton.filledTonal(onPressed: () => download(context), icon: const Icon(Icons.download)),
          ]),
        ),
      ),
    );
  }
}

class BillingSummaryCell extends StatelessWidget {
  const BillingSummaryCell({super.key, required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => CpCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Cp.onVariant, fontSize: 11, fontWeight: FontWeight.w800)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900))])),
        ]),
      );
}

class BillingDocumentCard extends StatelessWidget {
  const BillingDocumentCard({super.key, required this.title, required this.subtitle, required this.code, required this.amountLabel, required this.amount, required this.dateLabel, required this.status, required this.statusColor, required this.icon, required this.onDownload, this.onTap});
  final String title, subtitle, code, amountLabel, amount, dateLabel, status;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onDownload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Cp.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)), Text(code, style: const TextStyle(color: Cp.outline, fontSize: 11, fontWeight: FontWeight.w800))])),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Pill(status, color: statusColor.withValues(alpha: .14), textColor: statusColor),
                IconButton(onPressed: onDownload, icon: const Icon(Icons.download, color: Cp.primary), tooltip: 'Download'),
              ]),
            ]),
            const Divider(height: 22),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(amountLabel, style: const TextStyle(color: Cp.outline, fontSize: 11, fontWeight: FontWeight.w800)), Text(amount, style: const TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900))])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Date', style: TextStyle(color: Cp.outline, fontSize: 11, fontWeight: FontWeight.w800)), Text(dateLabel, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))])),
            ]),
          ]),
        ),
      );
}

class BillingDocumentDetailsScreen extends StatelessWidget {
  const BillingDocumentDetailsScreen({super.key, required this.event, required this.type, required this.api, this.payment});
  final AppEvent event;
  final String type;
  final ApiService api;
  final AppPayment? payment;

  bool get isInvoice => type == 'invoice';
  String get title => isInvoice ? 'Invoice Details' : 'Quotation Details';
  String get docCode => isInvoice ? 'INV-${(payment?.id ?? event.id).toUpperCase()}' : 'QUOTE-${event.id.toUpperCase()}';

  Future<Uri> documentUri() => api.documentUri(event.id, isInvoice ? 'invoice' : 'quotation');

  Future<void> download(BuildContext context) async {
    final uri = await documentUri();
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (context.mounted) showCpSnack(context, launched ? '${isInvoice ? 'Invoice' : 'Quotation'} download started' : 'Unable to start download');
  }

  Future<void> shareOverWhatsApp(BuildContext context) async {
    final uri = await documentUri();
    final label = isInvoice ? 'invoice' : 'quotation';
    final text = 'CaterPro $label for ${event.name}: $uri';
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  Future<void> requestPayment(BuildContext context) async {
    final pending = eventBalance(event);
    final client = event.primaryClient.isEmpty ? 'Customer' : event.primaryClient;
    final text = 'Hello $client, pending payment for ${event.name} is ${money(pending)}. Please complete the payment. - CaterPro';
    await launchUrl(Uri.parse('https://wa.me/${event.mobile}?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final total = eventTotal(event);
    final paid = eventPaid(event);
    final currentPayment = payment?.amount ?? 0;
    final pending = eventBalance(event);
    final clientName = event.primaryClient.isEmpty ? event.mobile : event.primaryClient;
    final menuCount = event.dates.fold<int>(0, (sum, date) => sum + date.menuSlots.length);
    final menuItems = event.dates.expand((date) => date.menuSlots).expand((slot) => slot.menuItemIds).length;
    return Scaffold(
      backgroundColor: Cp.background,
      body: ScreenFrame(
        topBar: TopBar(title: title, avatar: false, leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        bottomPadding: 98,
        children: [
          CpCard(
            color: isInvoice ? Cp.tertiaryFixed.withValues(alpha: .28) : Cp.primaryFixed.withValues(alpha: .42),
            child: Column(children: [
              CircleAvatar(radius: 28, backgroundColor: isInvoice ? Cp.tertiaryFixed : Cp.primaryFixed, child: Icon(isInvoice ? Icons.check : Icons.request_quote, color: isInvoice ? Cp.tertiaryContainer : Cp.primary, size: 34)),
              const SizedBox(height: 12),
              Text(isInvoice ? 'Payment recorded' : 'Quotation ready', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w900)),
              Text(isInvoice ? money(currentPayment) : money(total), style: const TextStyle(color: Cp.onSurface, fontSize: 30, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 12),
          DetailNavTile(iconText: clientName.isEmpty ? 'C' : clientName[0].toUpperCase(), label: 'Client Name', value: clientName),
          DetailNavTile(iconText: event.name.isEmpty ? 'E' : event.name[0].toUpperCase(), label: 'Event Name', value: event.name),
          CpCard(
            color: const Color(0xfffff7ff),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Event Date: ${event.dates.isEmpty ? '-' : event.dates.map((date) => date.date).join(', ')}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const Text('Terms: Due of Receipt', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: SmallInfoBlock(label: isInvoice ? 'Invoice#' : 'Quotation#', value: docCode)),
                const SizedBox(width: 12),
                Expanded(child: SmallInfoBlock(label: isInvoice ? 'Invoice Date' : 'Quotation Date', value: payment?.date ?? DateTime.now().toIso8601String().substring(0, 10))),
              ]),
              const Divider(height: 24),
              SmallInfoBlock(label: 'Event#', value: event.id.toUpperCase()),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            color: const Color(0xfffff7ff),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [Expanded(child: Text('Menu Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), Icon(Icons.chevron_right)]),
              const SizedBox(height: 8),
              Text('$menuCount menu slots • $menuItems selected items', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...event.dates.take(4).map((date) => Text('${date.date}: ${date.menuSlots.map((slot) => '${slot.type} ${slot.pax} pax').join(', ')}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            color: const Color(0xfffff7ff),
            child: Column(children: [
              AmountLine('Subtotal', money(total)),
              const Divider(height: 18),
              AmountLine('Grand Total', money(total), strong: true),
              AmountLine('Advance / Paid Till Now', money(paid), color: Cp.tertiaryContainer),
              if (isInvoice) AmountLine('Payment Made', money(currentPayment), color: Cp.tertiaryContainer),
              const Divider(height: 18),
              AmountLine('Pending', money(pending), color: pending == 0 ? Cp.tertiaryContainer : Cp.error, strong: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Cp.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: pending == 0 ? null : () => requestPayment(context),
                style: FilledButton.styleFrom(backgroundColor: Cp.secondaryContainer, foregroundColor: const Color(0xff694000), disabledBackgroundColor: Cp.surfaceHigh),
                child: Text(pending == 0 ? 'Payment Complete' : 'Request Payment', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(onPressed: () => download(context), icon: const Icon(Icons.download)),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: () => shareOverWhatsApp(context), icon: const Icon(Icons.chat)),
          ]),
        ),
      ),
    );
  }
}

class DetailNavTile extends StatelessWidget {
  const DetailNavTile({super.key, required this.iconText, required this.label, required this.value});
  final String iconText, label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          color: const Color(0xfffff7ff),
          child: Row(children: [
            CircleAvatar(backgroundColor: Cp.surfaceHigh, child: Text(iconText, style: const TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Cp.outline, fontSize: 11, fontWeight: FontWeight.w800)), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))])),
            const Icon(Icons.chevron_right, color: Cp.onVariant),
          ]),
        ),
      );
}

class SmallInfoBlock extends StatelessWidget {
  const SmallInfoBlock({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), Text(value, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))]);
}

class AmountLine extends StatelessWidget {
  const AmountLine(this.label, this.value, {super.key, this.color, this.strong = false});
  final String label, value;
  final Color? color;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: color ?? Cp.onVariant, fontWeight: strong ? FontWeight.w900 : FontWeight.w700))),
          Text(value, style: TextStyle(color: color ?? Cp.onSurface, fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );
}

void showRecordPaymentSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const RecordPaymentSheet(),
  );
}

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.code, required this.event, required this.amount, required this.dateLabel, required this.date, required this.status, required this.color, this.onTap});
  final String code, event, amount, dateLabel, date, status;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(code, style: const TextStyle(fontWeight: FontWeight.w900)), Text(event, style: const TextStyle(color: Cp.onVariant))])), Pill(status, color: color.withValues(alpha: .18), textColor: color, icon: status == 'Paid' ? Icons.check_circle : status == 'Overdue' ? Icons.warning : null)]),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Amount', style: TextStyle(color: Cp.outline, fontSize: 12)), Text(amount, style: TextStyle(color: color == Cp.error ? Cp.error : Cp.primary, fontSize: 22, fontWeight: FontWeight.w900))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(dateLabel, style: TextStyle(color: color == Cp.error ? Cp.error : Cp.outline, fontSize: 12, fontWeight: FontWeight.w700)), Text(date, style: const TextStyle(fontWeight: FontWeight.w700))])]),
        ]),
      ),
    );
  }
}

class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key});

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  static const int totalAmount = 350000;
  static const int paidAmount = 225000;
  static const int balanceAmount = 125000;
  final paymentController = TextEditingController(text: '50000');
  final dateController = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final refController = TextEditingController(text: 'REF123456789');
  final paymentModes = const ['Cash', 'UPI', 'NEFT', 'RTGS', 'Cheque'];
  int selectedMode = 0;
  bool settled = false;
  String? errorText;

  int get paymentAmount => int.tryParse(paymentController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get remainingAfterPayment => (balanceAmount - paymentAmount).clamp(0, balanceAmount);
  int get settledDiscount => settled && paymentAmount <= balanceAmount ? remainingAfterPayment : 0;
  int get finalBalance => settled && paymentAmount <= balanceAmount ? 0 : remainingAfterPayment;

  @override
  void dispose() {
    paymentController.dispose();
    dateController.dispose();
    refController.dispose();
    super.dispose();
  }

  String money(int value) {
    final text = value.toString();
    if (text.length <= 3) return '₹$text';
    final tail = text.substring(text.length - 3);
    var head = text.substring(0, text.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    return '₹${groups.join(',')},$tail';
  }

  bool validate() {
    if (paymentAmount <= 0) {
      setState(() => errorText = 'Enter a payment amount.');
      return false;
    }
    if (paymentAmount > balanceAmount) {
      setState(() => errorText = 'Payment cannot be more than remaining balance ${money(balanceAmount)}.');
      return false;
    }
    final dateError = isoDateValidator(dateController.text, label: 'Payment date');
    if (dateError != null) {
      setState(() => errorText = dateError);
      return false;
    }
    setState(() => errorText = null);
    return true;
  }

  void savePayment() {
    if (!validate()) return;
    final discount = settledDiscount;
    Navigator.pop(context);
    showCpSnack(
      context,
      discount > 0 ? 'Payment saved. ${money(discount)} marked as settled discount.' : 'Payment saved by ${paymentModes[selectedMode]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            const Text('Record Payment', style: TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Update the financial records for this event.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 18),
            CpCard(
              color: Cp.surfaceLow,
              child: Row(
                children: [
                  Expanded(child: _MoneyCell(label: 'Total', value: money(totalAmount))),
                  Expanded(child: _MoneyCell(label: 'Paid', value: money(paidAmount), color: Cp.tertiaryContainer)),
                  Expanded(child: _MoneyCell(label: 'Balance', value: money(balanceAmount), color: Cp.error)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PaymentInputBox(label: 'Payment Amount', controller: paymentController, icon: Icons.currency_rupee, keyboardType: TextInputType.number, onChanged: (_) => validate()),
            if (errorText != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(errorText!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
            Row(children: [Expanded(child: PaymentInputBox(label: 'Date', controller: dateController, icon: Icons.calendar_today)), const SizedBox(width: 12), Expanded(child: PaymentInputBox(label: 'Ref No.', controller: refController, icon: Icons.confirmation_number))]),
            const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(paymentModes.length, (i) {
                  final selected = i == selectedMode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => selectedMode = i),
                      child: Pill(paymentModes[i], color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: settled,
              activeColor: Cp.primary,
              onChanged: (value) => setState(() => settled = value ?? false),
              title: const Text('Mark balance as settled', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(settled ? '${money(settledDiscount)} will be treated as discount/settlement. Final balance: ${money(finalBalance)}' : 'Unchecked keeps ${money(remainingAfterPayment)} as pending balance.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: savePayment, style: FilledButton.styleFrom(backgroundColor: Cp.primary), icon: const Icon(Icons.save), label: const Text('Save Payment', style: TextStyle(fontWeight: FontWeight.w900)))),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)))),
          ],
        ),
      ),
    );
  }
}

class PaymentInputBox extends StatelessWidget {
  const PaymentInputBox({super.key, required this.label, required this.controller, this.icon, this.keyboardType, this.onChanged});
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
        decoration: BoxDecoration(border: Border.all(color: Cp.outline), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Cp.primary, fontSize: 13, fontWeight: FontWeight.w700),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (icon != null) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(icon, color: Cp.outline)),
          ],
        ),
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.label, required this.value, this.color = Cp.onSurface});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [Text(label, style: const TextStyle(color: Cp.outline, fontSize: 10, fontWeight: FontWeight.w900)), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900))]);
}

Uint8List? bytesFromDataUrl(String value) {
  if (value.isEmpty || !value.contains(',')) return null;
  try {
    return base64Decode(value.split(',').last);
  } catch (_) {
    return null;
  }
}

class BusinessLogoAvatar extends StatelessWidget {
  const BusinessLogoAvatar({super.key, required this.profile, this.radius = 24});
  final BusinessProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final logoBytes = bytesFromDataUrl(profile.logoBase64);
    final initials = profile.businessName.trim().isEmpty ? 'RC' : profile.businessName.trim().split(RegExp(r'\s+')).map((part) => part[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Cp.primaryContainer,
      backgroundImage: logoBytes == null ? null : MemoryImage(logoBytes),
      child: logoBytes == null ? Text(initials, style: TextStyle(color: Colors.white, fontSize: radius * .5, fontWeight: FontWeight.w900)) : null,
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.openBusiness, required this.openMenu, required this.openCustomMenus, required this.openEmployees, required this.openRawMaterials, required this.openProduceItems, required this.businessProfile, required this.services, required this.onSaveService, required this.onDeleteService});
  final VoidCallback openBusiness;
  final VoidCallback openMenu;
  final VoidCallback openCustomMenus;
  final VoidCallback openEmployees;
  final VoidCallback openRawMaterials;
  final VoidCallback openProduceItems;
  final BusinessProfile businessProfile;
  final List<AdditionalServiceItem> services;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

  void showSettingsInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      topBar: TopBar(title: 'CaterPro', avatar: false, actions: [IconButton(onPressed: () => showCpSnack(context, 'Notifications opened'), icon: const Icon(Icons.notifications, color: Cp.primary)), const CircleAvatar(radius: 16, backgroundColor: Cp.primaryContainer, child: Text('RC', style: TextStyle(fontSize: 10, color: Colors.white)))]),
      children: [
        CpCard(
          onTap: openBusiness,
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            BusinessLogoAvatar(profile: businessProfile, radius: 48),
            const SizedBox(height: 12),
            Text(businessProfile.businessName.isEmpty ? 'Business Profile' : businessProfile.businessName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(businessProfile.serviceType.isEmpty ? 'Add your business details' : businessProfile.serviceType, style: const TextStyle(color: Cp.onVariant)),
          ]),
        ),
        const SizedBox(height: 20),
        SettingsGroup(title: 'Business', items: [(Icons.storefront, 'Business Profile')], onItemTap: {'Business Profile': openBusiness}),
        SettingsGroup(title: 'Masters', items: [(Icons.restaurant_menu, 'Menu Master'), (Icons.fact_check, 'Custom Menus'), (Icons.room_service, 'Additional Services'), (Icons.inventory_2, 'Raw Materials'), (Icons.eco, 'Vegetables & Fruits')], onItemTap: {'Menu Master': openMenu, 'Custom Menus': openCustomMenus, 'Additional Services': () => showAdditionalServiceManager(context, services: services, onSave: onSaveService, onDelete: onDeleteService), 'Raw Materials': openRawMaterials, 'Vegetables & Fruits': openProduceItems}),
        SettingsGroup(title: 'Team', items: [(Icons.badge, 'Employees'), (Icons.manage_accounts, 'User Management')], onItemTap: {'Employees': openEmployees, 'User Management': () => showSettingsInfo(context, 'User Management', 'User access and roles will be connected after multi-user backend permissions are added.')}),
        SettingsGroup(title: 'Preferences', items: [(Icons.description, 'Invoice Settings'), (Icons.notifications_active, 'Notifications'), (Icons.light_mode, 'App Appearance')], onItemTap: {
          'Invoice Settings': openBusiness,
          'Notifications': () => showSettingsInfo(context, 'Notifications', 'Notification preferences will be used for payment reminders, event follow-ups, and daily summaries.'),
          'App Appearance': () => showSettingsInfo(context, 'App Appearance', 'The current theme is optimized for the CaterPro workflow. More appearance options can be added later.'),
        }),
        SettingsGroup(title: 'Data', items: [(Icons.file_download, 'Export Data'), (Icons.history_edu, 'Audit Log')], onItemTap: {
          'Export Data': () => showSettingsInfo(context, 'Export Data', 'Data export will package events, clients, menus, invoices, and payments after the production database is finalized.'),
          'Audit Log': () => showSettingsInfo(context, 'Audit Log', 'Audit history will show edits, payments, document downloads, and sync events.'),
        }),
        Center(
          child: TextButton(
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
            child: const Padding(padding: EdgeInsets.all(18), child: Text('Logout', style: TextStyle(color: Cp.error, fontSize: 16, fontWeight: FontWeight.w800))),
          ),
        ),
      ],
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.items, this.onItemTap = const {}});
  final String title;
  final List<(IconData, String)> items;
  final Map<String, VoidCallback> onItemTap;
  @override
  Widget build(BuildContext context) {
    void fallback(String label) => showCpSnack(context, '$label opened');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: Text(title, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w800))),
        Material(
          color: Cp.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          child: Column(children: List.generate(items.length, (i) {
            final label = items[i].$2;
            return ListTile(
              onTap: onItemTap[label] ?? () => fallback(label),
              leading: Icon(items[i].$1, color: Cp.onVariant),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right, color: Cp.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          })),
        ),
      ]),
    );
  }
}

void showAdditionalServiceManager(
  BuildContext context, {
  required List<AdditionalServiceItem> services,
  required ValueChanged<AdditionalServiceItem> onSave,
  required ValueChanged<String> onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AdditionalServiceManagerSheet(services: services, onSave: onSave, onDelete: onDelete),
  );
}

void showEventRecordPaymentSheet(BuildContext context, {required AppEvent event, required ApiService api, required ValueChanged<AppEvent> onSaved}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EventRecordPaymentSheet(event: event, api: api, onSaved: onSaved),
  );
}

class EventRecordPaymentSheet extends StatefulWidget {
  const EventRecordPaymentSheet({super.key, required this.event, required this.api, required this.onSaved});
  final AppEvent event;
  final ApiService api;
  final ValueChanged<AppEvent> onSaved;

  @override
  State<EventRecordPaymentSheet> createState() => _EventRecordPaymentSheetState();
}

class _EventRecordPaymentSheetState extends State<EventRecordPaymentSheet> {
  late final TextEditingController paymentController;
  late final TextEditingController dateController;
  late final TextEditingController refController;
  final paymentModes = ['Cash', 'UPI', 'NEFT', 'RTGS', 'Cheque'];
  int selectedMode = 0;
  bool settled = false;
  bool saving = false;
  String? errorText;

  int get totalAmount => eventTotal(widget.event);
  int get paidAmount => eventPaid(widget.event);
  int get balanceAmount => eventBalance(widget.event);
  int get paymentAmount => int.tryParse(paymentController.text.replaceAll(',', '').trim()) ?? 0;
  int get remainingAfterPayment => (balanceAmount - paymentAmount).clamp(0, balanceAmount);
  int get settledDiscount => settled && paymentAmount <= balanceAmount ? remainingAfterPayment : 0;
  int get finalBalance => settled && paymentAmount <= balanceAmount ? 0 : remainingAfterPayment;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    paymentController = TextEditingController();
    dateController = TextEditingController(text: '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
    refController = TextEditingController();
  }

  @override
  void dispose() {
    paymentController.dispose();
    dateController.dispose();
    refController.dispose();
    super.dispose();
  }

  void validate() {
    final amount = paymentAmount;
    setState(() {
      if (amount <= 0) {
        errorText = 'Enter a payment amount.';
      } else if (amount > balanceAmount) {
        errorText = 'Payment cannot be more than remaining balance ${money(balanceAmount)}.';
      } else if (isoDateValidator(dateController.text, label: 'Payment date') != null) {
        errorText = isoDateValidator(dateController.text, label: 'Payment date');
      } else {
        errorText = null;
      }
    });
  }

  Future<void> savePayment() async {
    validate();
    if (errorText != null || saving) return;
    setState(() => saving = true);
    try {
      final updated = await widget.api.recordPayment(
        widget.event.id,
        amount: paymentAmount,
        date: dateController.text.trim(),
        mode: paymentModes[selectedMode],
        reference: refController.text.trim(),
        settled: settled,
        settledDiscount: settledDiscount,
      );
      widget.onSaved(updated);
      if (!mounted) return;
      Navigator.pop(context);
      showCpSnack(context, settledDiscount > 0 ? 'Payment saved. ${money(settledDiscount)} marked as settlement discount.' : 'Payment saved.');
    } catch (e) {
      if (mounted) setState(() => errorText = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 22), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Text('Record Payment - ${widget.event.name}', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const Text('Payment amount must be less than or equal to the remaining balance.', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            CpCard(color: Cp.surfaceLow, child: Row(children: [
              Expanded(child: _MoneyCell(label: 'Total', value: money(totalAmount))),
              Expanded(child: _MoneyCell(label: 'Paid', value: money(paidAmount), color: Cp.tertiaryContainer)),
              Expanded(child: _MoneyCell(label: 'Balance', value: money(balanceAmount), color: Cp.error)),
            ])),
            const SizedBox(height: 16),
            PaymentInputBox(label: 'Payment Amount', controller: paymentController, icon: Icons.currency_rupee, keyboardType: TextInputType.number, onChanged: (_) => validate()),
            Row(children: [Expanded(child: PaymentInputBox(label: 'Date', controller: dateController, icon: Icons.calendar_today)), const SizedBox(width: 12), Expanded(child: PaymentInputBox(label: 'Ref No.', controller: refController, icon: Icons.confirmation_number))]),
            const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(paymentModes.length, (index) {
                final selected = selectedMode == index;
                return ChoiceChip(
                  selected: selected,
                  label: Text(paymentModes[index]),
                  selectedColor: Cp.primaryContainer,
                  labelStyle: TextStyle(color: selected ? Colors.white : Cp.onVariant, fontWeight: FontWeight.w800),
                  onSelected: (_) => setState(() => selectedMode = index),
                );
              }),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: settled,
              onChanged: (value) => setState(() => settled = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Cp.primary,
              title: const Text('Settled', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(settled ? '${money(settledDiscount)} will be treated as discount/settlement. Final balance: ${money(finalBalance)}' : 'Unchecked keeps ${money(remainingAfterPayment)} as pending balance.'),
            ),
            if (errorText != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(errorText!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: saving ? null : savePayment, style: FilledButton.styleFrom(backgroundColor: Cp.primary), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save Payment', style: const TextStyle(fontWeight: FontWeight.w900)))),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)))),
          ]),
        ),
      ),
    );
  }
}

class AdditionalServiceManagerSheet extends StatelessWidget {
  const AdditionalServiceManagerSheet({super.key, required this.services, required this.onSave, required this.onDelete});
  final List<AdditionalServiceItem> services;
  final ValueChanged<AdditionalServiceItem> onSave;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Row(children: [
              const Expanded(child: Text('Additional Services', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => showServiceEditor(context, onSave: onSave), icon: const Icon(Icons.add_circle, color: Cp.primary)),
            ]),
            const Text('Add, update, or remove services used in event menu configuration.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return CpCard(
                    color: Cp.card,
                    child: Row(children: [
                      const Icon(Icons.room_service, color: Cp.secondary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(serviceLine(service.name, service.quantity, service.unit, service.price), style: const TextStyle(fontWeight: FontWeight.w800))),
                      IconButton(onPressed: () => showServiceEditor(context, service: service, onSave: onSave), icon: const Icon(Icons.edit, color: Cp.primary)),
                      IconButton(onPressed: () => onDelete(service.id), icon: const Icon(Icons.delete, color: Cp.error)),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showServiceEditor(BuildContext context, {AdditionalServiceItem? service, required ValueChanged<AdditionalServiceItem> onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ServiceEditorSheet(service: service, onSave: onSave),
  );
}

class ServiceEditorSheet extends StatefulWidget {
  const ServiceEditorSheet({super.key, this.service, required this.onSave});
  final AdditionalServiceItem? service;
  final ValueChanged<AdditionalServiceItem> onSave;

  @override
  State<ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<ServiceEditorSheet> {
  late final TextEditingController id;
  late final TextEditingController name;
  late final TextEditingController unit;
  late final TextEditingController quantity;
  late final TextEditingController price;
  String? error;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    id = TextEditingController(text: service?.id ?? 'SRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    name = TextEditingController(text: service?.name ?? '');
    unit = TextEditingController(text: service?.unit ?? 'pcs');
    quantity = TextEditingController(text: '${service?.quantity ?? 0}');
    price = TextEditingController(text: '${service?.price ?? 0}');
  }

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    unit.dispose();
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
          Text(widget.service == null ? 'Add Service' : 'Update Service', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          EditableInlineField(label: 'Service ID', controller: id),
          EditableInlineField(label: 'Service Name', controller: name),
          Row(children: [Expanded(child: EditableInlineField(label: 'Quantity', controller: quantity, keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: EditableInlineField(label: 'Unit', controller: unit))]),
          EditableInlineField(label: 'Price', controller: price, keyboardType: TextInputType.number),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer),
              onPressed: () {
                final parsedQuantity = int.tryParse(quantity.text.trim());
                final parsedPrice = int.tryParse(price.text.trim());
                if (id.text.trim().isEmpty || name.text.trim().isEmpty || unit.text.trim().isEmpty || parsedQuantity == null || parsedQuantity < 0 || parsedPrice == null || parsedPrice < 0) {
                  setState(() => error = 'Enter service ID, name, unit, and valid quantity/price.');
                  return;
                }
                widget.onSave(AdditionalServiceItem(id: id.text.trim(), name: name.text.trim(), unit: unit.text.trim(), quantity: parsedQuantity, price: parsedPrice));
                Navigator.pop(context);
              },
              child: const Text('Save Service', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

class EditableInlineField extends StatelessWidget {
  const EditableInlineField({super.key, required this.label, required this.controller, this.keyboardType, this.inputFormatters});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.initialEvent, required this.onDraftSaved, required this.onClose, required this.onCreate, required this.services, required this.customMenus, required this.customerEvents, required this.onSaveService, required this.onDeleteService});
  final AppEvent? initialEvent;
  final ValueChanged<AppEvent> onDraftSaved;
  final VoidCallback onClose;
  final Future<void> Function(EventDraft draft) onCreate;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final List<AppEvent> customerEvents;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final api = ApiService();
  int step = 0;
  bool saving = false;
  bool autosaving = false;
  String? error;
  late final EventDraft draft;

  @override
  void initState() {
    super.initState();
    draft = widget.initialEvent == null ? EventDraft() : EventDraft.fromEvent(widget.initialEvent!);
  }

  List<CustomerSuggestion> get customerSuggestions {
    final byMobile = <String, CustomerSuggestion>{};
    for (final event in widget.customerEvents) {
      final mobile = normalizeMobileNumber(event.mobile);
      if (mobile.isEmpty) continue;
      final name = event.primaryClient.isEmpty ? event.name : event.primaryClient;
      byMobile[mobile] = CustomerSuggestion(name: name, mobile: mobile);
    }
    final list = byMobile.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> save() async {
    draft.mobile = normalizeMobileNumber(draft.mobile);
    final saveError = validateEventForFinalSave();
    if (saveError != null) {
      setState(() => error = saveError);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onCreate(draft);
      if (!mounted) return;
      showCpSnack(context, widget.initialEvent == null ? 'Event created' : 'Event updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? validateDetails() {
    draft.mobile = normalizeMobileNumber(draft.mobile);
    if (draft.name.trim().isEmpty) return 'Event name is required.';
    if (draft.client.trim().isEmpty) return 'Primary client is required.';
    if (draft.mobile.trim().isEmpty) return 'Mobile number is required.';
    if (draft.mobile.length != 10) return 'Mobile number must be 10 digits.';
    return null;
  }

  String? validateEventForFinalSave() {
    final detailsError = validateDetails();
    if (detailsError != null) return detailsError;
    if (draft.dates.isEmpty) return 'Add at least one event date.';
    for (final date in draft.dates) {
      final dateError = isoDateValidator(date.date, label: 'Event date', noPast: true);
      if (dateError != null) return dateError;
      for (final slot in date.slots.where((item) => item.enabled)) {
        final pax = int.tryParse(slot.pax.trim()) ?? 0;
        if (pax <= 0) return '${slot.type} pax must be more than zero.';
        if (slot.pricePerPax <= 0) return '${slot.type} price per pax must be more than zero.';
      }
    }
    return null;
  }

  Future<bool> autosaveDraft() async {
    if (autosaving) return true;
    final detailsError = validateDetails();
    if (detailsError != null) {
      setState(() => error = detailsError);
      return false;
    }
    setState(() {
      autosaving = true;
      error = null;
    });
    try {
      final saved = await api.saveEventDraft(draft, eventId: draft.id);
      draft.id = saved.id;
      widget.onDraftSaved(saved);
      return true;
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      if (mounted) setState(() => autosaving = false);
    }
  }

  Future<void> goNext() async {
    if (step == 0) {
      final detailsError = validateDetails();
      if (detailsError != null) {
        setState(() => error = detailsError);
        return;
      }
    }
    final saved = await autosaveDraft();
    if (!saved || !mounted) return;
    setState(() {
      error = null;
      step++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      bottomPadding: 24,
      topBar: TopBar(
        title: step == 2 ? 'Menu Configuration' : widget.initialEvent == null ? 'Create Event' : 'Edit Event',
        avatar: false,
        leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)),
        actions: [if (autosaving) const Padding(padding: EdgeInsets.only(right: 14), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Cp.primary))))],
      ),
      children: [
        StepperHeader(active: step),
        const SizedBox(height: 24),
        if (error != null) ...[CpCard(color: Cp.errorContainer, child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))), const SizedBox(height: 12)],
        if (step == 0) CreateDetailsStep(draft: draft, customers: customerSuggestions, onChanged: () => setState(() => error = null)),
        if (step == 1) CreateDatesStep(dates: draft.dates, onChanged: () { setState(() {}); autosaveDraft(); }),
        if (step == 2) CreateMenuStep(dates: draft.dates, services: widget.services, customMenus: widget.customMenus, onChanged: () => autosaveDraft(), onSaveService: widget.onSaveService, onDeleteService: widget.onDeleteService),
        if (step == 3) CreateReviewStep(draft: draft, onChanged: () { setState(() {}); autosaveDraft(); }),
        const SizedBox(height: 20),
        Row(
          children: [
            if (step > 0) Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back), label: const Text('Back'))),
            if (step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: saving || autosaving ? null : () => step == 3 ? save() : goNext(),
                  style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer),
                  label: Text(saving ? 'Saving...' : step == 0 ? 'Next: Add Dates' : step == 1 ? 'Next: Add Menus' : step == 2 ? 'Next: Review' : widget.initialEvent == null ? 'Create Event' : 'Save Event', style: const TextStyle(fontWeight: FontWeight.w900)),
                  icon: Icon(step == 3 ? Icons.check : Icons.arrow_forward),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CreateDetailsStep extends StatefulWidget {
  const CreateDetailsStep({super.key, required this.draft, required this.customers, required this.onChanged});
  final EventDraft draft;
  final List<CustomerSuggestion> customers;
  final VoidCallback onChanged;

  @override
  State<CreateDetailsStep> createState() => _CreateDetailsStepState();
}

class _CreateDetailsStepState extends State<CreateDetailsStep> {
  List<CustomerSuggestion> matches = [];

  void updateMatches(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      matches = q.isEmpty
          ? []
          : widget.customers.where((customer) => customer.name.toLowerCase().contains(q) || customer.mobile.contains(q)).take(6).toList();
    });
  }

  void selectCustomer(CustomerSuggestion customer) {
    setState(() {
      widget.draft.client = customer.name;
      widget.draft.mobile = customer.mobile;
      matches = [];
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.assignment, color: Cp.primary), SizedBox(width: 8), Text('Event Fundamentals', style: TextStyle(fontSize: 20, color: Cp.primary, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 20),
          FormFieldBox(label: 'Event Name', value: widget.draft.name, onChanged: (value) { widget.draft.name = value; widget.onChanged(); }),
          FormFieldBox(
            label: 'Primary Client',
            value: widget.draft.client,
            icon: Icons.person_search,
            onChanged: (value) {
              widget.draft.client = value;
              updateMatches(value);
              widget.onChanged();
            },
          ),
          if (matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Cp.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: matches
                      .map((customer) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, color: Cp.primary),
                            title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(customer.mobile),
                            onTap: () => selectCustomer(customer),
                          ))
                      .toList(),
                ),
              ),
            ),
          FormFieldBox(label: 'Mobile Number (Unique Customer ID)', value: widget.draft.mobile, icon: Icons.phone_iphone, inputFormatters: mobileInputFormatters, onChanged: (value) { widget.draft.mobile = normalizeMobileNumber(value); updateMatches(widget.draft.mobile); widget.onChanged(); }),
          FormFieldBox(label: 'Venue', value: widget.draft.venue, icon: Icons.location_on, onChanged: (value) { widget.draft.venue = value; widget.onChanged(); }),
          FormFieldBox(label: 'Event Notes & Logistics', value: widget.draft.notes, height: 98, onChanged: (value) { widget.draft.notes = value; widget.onChanged(); }),
        ]),
      ),
    ]);
  }
}

class CreateDatesStep extends StatelessWidget {
  const CreateDatesStep({super.key, required this.dates, required this.onChanged});
  final List<DraftDateConfig> dates;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Event Dates', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
      const Text('Add every date in the event schedule. Pax is configured later for each date and menu type.', style: TextStyle(color: Cp.onVariant)),
      const SizedBox(height: 16),
      if (dates.isEmpty) const EmptyStateCard(title: 'No dates added', message: 'Add each event date. Pax is configured per menu type later.'),
      ...dates.map((date) => DateScheduleCard(month: shortMonthLabel(date.date), day: dayLabel(date.date), title: date.label.isEmpty ? 'Event Date' : date.label, summary: readableDateLabel(date.date), onDelete: () { dates.remove(date); onChanged(); })),
      DashedAction(label: 'Add Date', icon: Icons.add_circle, onTap: () async {
        final date = await showAddDateSheet(context);
        if (date != null) {
          dates.add(date);
          onChanged();
        }
      }),
    ]);
  }
}

Future<DraftDateConfig?> showAddDateSheet(BuildContext context) {
  final dateController = TextEditingController();
  final labelController = TextEditingController();
  DateTime? selectedDate;
  final today = DateTime.now();
  final firstDate = DateTime(today.year, today.month, today.day);
  String formatDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return showModalBottomSheet<DraftDateConfig>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            const Text('Add Event Date', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const Text('Select a date. Previous dates are disabled.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? firstDate,
                  firstDate: firstDate,
                  lastDate: DateTime(firstDate.year + 5),
                );
                if (picked == null) return;
                setSheetState(() {
                  selectedDate = picked;
                  dateController.text = formatDate(picked);
                });
              },
              child: IgnorePointer(child: EditableInlineField(label: 'Event Date', controller: dateController)),
            ),
            EditableInlineField(label: 'Date Label', controller: labelController),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: selectedDate == null ? null : () => Navigator.pop(context, DraftDateConfig(date: dateController.text.trim(), label: labelController.text.trim())),
                  style: FilledButton.styleFrom(backgroundColor: Cp.secondaryContainer, foregroundColor: const Color(0xff694000)),
                  child: const Text('Save Date'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class DateScheduleCard extends StatelessWidget {
  const DateScheduleCard({super.key, required this.month, required this.day, required this.title, required this.summary, this.onDelete});
  final String month, day, title, summary;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(child: Row(children: [Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Cp.primaryFixed, borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(month, style: const TextStyle(color: Cp.primary, fontSize: 11, fontWeight: FontWeight.w900)), Text(day, style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900))])), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text(summary, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))])), if (onDelete != null) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Cp.error))])),
      );
}

class CreateMenuStep extends StatefulWidget {
  const CreateMenuStep({super.key, required this.dates, required this.services, required this.customMenus, required this.onChanged, required this.onSaveService, required this.onDeleteService});
  final List<DraftDateConfig> dates;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final VoidCallback onChanged;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

  @override
  State<CreateMenuStep> createState() => _CreateMenuStepState();
}

class _CreateMenuStepState extends State<CreateMenuStep> {
  int selectedDateIndex = 0;

  DraftDateConfig? get currentConfig => widget.dates.isEmpty ? null : widget.dates[selectedDateIndex.clamp(0, widget.dates.length - 1)];

  @override
  Widget build(BuildContext context) {
    final config = currentConfig;
    if (config == null) {
      return const EmptyStateCard(title: 'Add dates first', message: 'Menu configuration is available after you add at least one event date.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        children: List.generate(widget.dates.length, (index) {
          final selected = index == selectedDateIndex;
          return ChoiceChip(
            selected: selected,
            label: Text(readableDateLabel(widget.dates[index].date)),
            selectedColor: Cp.primaryContainer,
            labelStyle: TextStyle(color: selected ? Colors.white : Cp.onVariant, fontWeight: FontWeight.w800),
            onSelected: (_) => setState(() => selectedDateIndex = index),
          );
        }),
      ),
      const SizedBox(height: 16),
      if (config.slots.isEmpty)
        CpCard(
          color: Cp.surfaceLow,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Icon(Icons.event_note, color: Cp.outline),
            SizedBox(height: 10),
            Text('No menu configured for this date yet.', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
            Text('Add only the menu types and services needed for this date.', style: TextStyle(color: Cp.onVariant)),
          ]),
        )
      else
        ...config.slots.map((slot) => MealSlotCard(
              key: ValueKey('${config.label}-${slot.type}'),
              slot: slot,
              items: selectedMenuTitles(slot),
              onEnabledChanged: (value) { setState(() => slot.enabled = value); widget.onChanged(); },
              onPaxChanged: (value) { setState(() => slot.pax = value); widget.onChanged(); },
              onPriceChanged: (value) { setState(() => slot.pricePerPax = int.tryParse(value) ?? 0); widget.onChanged(); },
              onEditMenu: () => openMenuPicker(slot),
              onDelete: () { setState(() => config.slots.remove(slot)); widget.onChanged(); },
            )),
      const SizedBox(height: 4),
      DashedAction(label: 'Add Menu Type', icon: Icons.add_circle, onTap: openMealTypePicker),
      const SizedBox(height: 12),
      const Text('Additional Services', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (config.additionalServices.isEmpty)
        const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('No additional services for this date.', style: TextStyle(color: Cp.onVariant, fontStyle: FontStyle.italic)))
      else
        ...config.additionalServices.map((service) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(child: Row(children: [Expanded(child: Text(additionalServiceLine(service), style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(onPressed: () { setState(() => config.additionalServices.remove(service)); widget.onChanged(); }, icon: const Icon(Icons.delete, color: Cp.error))])),
            )),
      const SizedBox(height: 12),
      DashedAction(label: 'Add Service', icon: Icons.add_circle, onTap: openServicePicker),
    ]);
  }

  List<String> selectedMenuTitles(MealSlotConfig slot) {
    return slot.selectedMenuIds.map((id) => menuItemById(id)?.english ?? id).toList();
  }

  void openMenuPicker(MealSlotConfig slot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MenuPickerScreen(
          meal: slot.type,
          selectedIds: slot.selectedMenuIds,
          customMenus: widget.customMenus,
          onChanged: (ids) { setState(() => slot.selectedMenuIds = {...ids}); widget.onChanged(); },
        ),
      ),
    );
  }

  void openMealTypePicker() {
    const availableTypes = [
      ('Breakfast', '8:00 AM', 0),
      ('Juice', '5:00 PM', 0),
      ('Lunch', '1:30 PM', 0),
      ('Snack', '4:30 PM', 0),
      ('Dinner', '8:00 PM', 0),
    ];
    final config = currentConfig;
    if (config == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .78),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Text('Add Menu Type for ${readableDateLabel(config.date)}', style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: availableTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final type = availableTypes[index];
                  final exists = config.slots.any((slot) => slot.type == type.$1);
                  return CpCard(
                    color: exists ? Cp.surfaceLow : Cp.card,
                    onTap: exists
                        ? null
                        : () {
                            setState(() => config.slots.add(MealSlotConfig(type: type.$1, time: type.$2, pax: '', pricePerPax: type.$3)));
                            widget.onChanged();
                            Navigator.pop(context);
                          },
                    child: Row(children: [
                      Icon(exists ? Icons.check_circle : Icons.add_circle, color: exists ? Cp.outline : Cp.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(exists ? '${type.$1} already added' : type.$1, style: const TextStyle(fontWeight: FontWeight.w900))),
                      Text(type.$2, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void openServicePicker() {
    final config = currentConfig;
    if (config == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServicePickerSheet(
        services: widget.services,
        selectedServices: config.additionalServices,
        onChanged: (selectedServices) {
          setState(() {
            config.additionalServices
              ..clear()
              ..addAll(selectedServices);
          });
          widget.onChanged();
        },
      ),
    );
  }
}

class DateMenuConfig {
  DateMenuConfig({required this.label, List<MealSlotConfig>? slots, Set<String>? selectedServiceIds})
      : slots = slots ?? <MealSlotConfig>[],
        selectedServiceIds = selectedServiceIds ?? <String>{};

  final String label;
  final List<MealSlotConfig> slots;
  final Set<String> selectedServiceIds;
}

class MealSlotConfig {
  MealSlotConfig({this.id, required this.type, required this.time, required this.pax, required this.pricePerPax, Set<String>? selectedMenuIds, this.enabled = true}) : selectedMenuIds = selectedMenuIds ?? <String>{};

  String? id;
  final String type;
  final String time;
  String pax;
  int pricePerPax;
  Set<String> selectedMenuIds;
  bool enabled;

  factory MealSlotConfig.fromEventSlot(AppMenuSlot slot) {
    return MealSlotConfig(id: slot.id, type: slot.type, time: slot.time, pax: slot.pax.toString(), pricePerPax: slot.pricePerPax, selectedMenuIds: slot.menuItemIds.toSet(), enabled: slot.enabled);
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'type': type,
        'time': time,
        'pax': int.tryParse(pax) ?? 0,
        'pricePerPax': pricePerPax,
        'enabled': enabled,
        'menuItemIds': selectedMenuIds.toList(),
      };
}

class ServicePickerSheet extends StatefulWidget {
  const ServicePickerSheet({super.key, required this.services, required this.selectedServices, required this.onChanged});
  final List<AdditionalServiceItem> services;
  final List<Map<String, dynamic>> selectedServices;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<ServicePickerSheet> {
  late Set<String> selectedIds;
  final quantityControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    selectedIds = widget.selectedServices.map((service) => service['serviceId'].toString()).toSet();
    for (final service in widget.services) {
      final selected = widget.selectedServices.where((item) => item['serviceId'] == service.id).firstOrNull;
      final quantity = (selected?['quantity'] as num?)?.toInt() ?? service.quantity;
      quantityControllers[service.id] = TextEditingController(text: quantity > 0 ? '$quantity' : '');
    }
  }

  @override
  void dispose() {
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = [...widget.services]..sort((a, b) {
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0).compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.name.compareTo(b.name);
      });

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
          const Text('Add Service', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
          const Text('Choose services from Settings > Additional Services.', style: TextStyle(color: Cp.onVariant)),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final service = services[index];
                final selected = selectedIds.contains(service.id);
                return CpCard(
                  color: selected ? Cp.primaryFixed : Cp.card,
                  onTap: () => setState(() => selected ? selectedIds.remove(service.id) : selectedIds.add(service.id)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 10), child: Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Cp.primary : Cp.outline)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(serviceLine(service.name, int.tryParse(quantityControllers[service.id]?.text ?? '') ?? service.quantity, service.unit, service.price), style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (selected) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: quantityControllers[service.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Count', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          onTap: () {},
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer),
              onPressed: () {
                for (final service in widget.services.where((service) => selectedIds.contains(service.id))) {
                  final raw = quantityControllers[service.id]?.text.trim() ?? '';
                  final quantity = int.tryParse(raw);
                  if (raw.isNotEmpty && (quantity == null || quantity < 0)) {
                    showCpSnack(context, 'Enter a valid count for ${service.name}');
                    return;
                  }
                }
                widget.onChanged(widget.services.where((service) => selectedIds.contains(service.id)).map((service) {
                  final quantity = int.tryParse(quantityControllers[service.id]?.text.trim() ?? '') ?? 0;
                  return {'serviceId': service.id, 'name': service.name, 'quantity': quantity, 'unit': service.unit, 'price': service.price};
                }).toList());
                Navigator.pop(context);
              },
              child: const Text('Apply Services', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

class AdditionalServiceCard extends StatelessWidget {
  const AdditionalServiceCard({super.key, required this.service, required this.onDelete});
  final AdditionalServiceItem service;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CpCard(
          color: Cp.surfaceLow,
          child: Row(children: [
            const Icon(Icons.flatware, color: Cp.secondary),
            const SizedBox(width: 12),
            Expanded(child: Text(serviceLine(service.name, service.quantity, service.unit, service.price), style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => onDelete(service.id), icon: const Icon(Icons.delete, color: Cp.error)),
          ]),
        ),
      );
}

class MenuPickerScreen extends StatefulWidget {
  const MenuPickerScreen({super.key, required this.meal, required this.selectedIds, required this.customMenus, required this.onChanged});
  final String meal;
  final Set<String> selectedIds;
  final List<CustomMenu> customMenus;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<MenuPickerScreen> createState() => _MenuPickerScreenState();
}

class _MenuPickerScreenState extends State<MenuPickerScreen> {
  late Set<String> selectedIds;
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedIds = {...widget.selectedIds};
  }

  @override
  Widget build(BuildContext context) {
    final items = MenuMasterScreen.menuItems.where((item) => item.title.toLowerCase().contains(query.toLowerCase()) || item.english.toLowerCase().contains(query.toLowerCase()) || item.kannada.contains(query)).toList()
      ..sort((a, b) {
        final aOrder = selectedOrder(a.id, selectedIds);
        final bOrder = selectedOrder(b.id, selectedIds);
        if (aOrder != -1 && bOrder != -1) return aOrder.compareTo(bOrder);
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0).compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.english.compareTo(b.english);
      });

    return Scaffold(
      backgroundColor: Cp.background,
      appBar: AppBar(
        backgroundColor: Cp.surface,
        foregroundColor: Cp.primary,
        title: Text('Select ${widget.meal} Menu'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onChanged(selectedIds);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashedAction(label: 'Select From Ready Made Menus', icon: Icons.fact_check, onTap: openReadyMadeMenuPicker),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search menu items', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final selected = selectedIds.contains(item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                color: selected ? Cp.primaryFixed : Cp.card,
                onTap: () => setState(() => selected ? selectedIds.remove(item.id) : selectedIds.add(item.id)),
                child: Row(children: [
                  Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Cp.primary : Cp.outline),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${item.id} • ${item.category} • ${item.meals}', style: const TextStyle(color: Cp.onVariant))])),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  void openReadyMadeMenuPicker() {
    final menus = widget.customMenus.where((menu) => menu.type == widget.meal).toList()..sort((a, b) => a.name.compareTo(b.name));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .72),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Text('Ready Made ${widget.meal} Menus', style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('Selecting one will add all its items. You can still add extra items below.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 14),
            if (menus.isEmpty)
              const EmptyStateCard(title: 'No ready made menus', message: 'Add custom menus from Settings > Custom Menus.')
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: menus.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final menu = menus[index];
                    return CpCard(
                      onTap: () {
                        setState(() => selectedIds.addAll(menu.itemIds));
                        Navigator.pop(context);
                        showCpSnack(context, '${menu.name} items selected');
                      },
                      child: Row(children: [
                        const Icon(Icons.playlist_add_check, color: Cp.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${menu.name}\n${menu.itemIds.length} items', style: const TextStyle(fontWeight: FontWeight.w900))),
                      ]),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class MealSlotCard extends StatelessWidget {
  const MealSlotCard({super.key, required this.slot, required this.items, required this.onEnabledChanged, required this.onPaxChanged, required this.onPriceChanged, required this.onEditMenu, required this.onDelete});
  final MealSlotConfig slot;
  final List<String> items;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onPaxChanged;
  final ValueChanged<String> onPriceChanged;
  final VoidCallback onEditMenu;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.enabled;
    return Opacity(
      opacity: enabled ? 1 : .58,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          color: enabled ? Cp.card : Cp.surfaceLow,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.restaurant_menu, color: enabled ? Cp.primary : Cp.outline),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(slot.type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(enabled ? '${slot.time} • ${slot.pax.isEmpty ? 0 : slot.pax} pax' : 'Not Scheduled • 0 pax', style: const TextStyle(color: Cp.onVariant))])),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Cp.error)),
              Switch(value: enabled, activeThumbColor: Cp.primary, onChanged: onEnabledChanged),
            ]),
            if (enabled) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: FormFieldBox(label: '${slot.type} Pax', value: slot.pax, icon: Icons.person, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: onPaxChanged)),
                const SizedBox(width: 12),
                Expanded(child: FormFieldBox(label: 'Price / Pax', value: slot.pricePerPax == 0 ? '' : '${slot.pricePerPax}', icon: Icons.currency_rupee, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: onPriceChanged)),
              ]),
            ],
            if (enabled) ...[
              const SizedBox(height: 12),
              if (items.isEmpty) const Text('No menu items selected.', style: TextStyle(color: Cp.onVariant, fontStyle: FontStyle.italic)) else Wrap(spacing: 8, runSpacing: 8, children: items.map((e) => Pill(e, color: Cp.surfaceHigh)).toList()),
              const Divider(height: 24),
              Row(children: [Text('₹${slot.pricePerPax}/pax', style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)), const Spacer(), InkWell(onTap: onEditMenu, child: const Row(children: [Icon(Icons.edit, color: Cp.primary, size: 18), Text(' Edit Menu', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800))]))]),
            ],
            if (!enabled) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Menu slot is currently disabled.', style: TextStyle(color: Cp.onVariant, fontStyle: FontStyle.italic))),
          ]),
        ),
      ),
    );
  }
}

class CreateReviewStep extends StatelessWidget {
  const CreateReviewStep({super.key, required this.draft, required this.onChanged});
  final EventDraft draft;
  final VoidCallback onChanged;

  int get menuTotal => draft.dates.fold(0, (dateSum, date) => dateSum + date.slots.where((slot) => slot.enabled).fold(0, (slotSum, slot) => slotSum + (int.tryParse(slot.pax) ?? 0) * slot.pricePerPax));
  int get serviceTotal => draft.dates.fold(0, (dateSum, date) => dateSum + date.additionalServices.fold(0, (sum, service) => sum + ((service['price'] as num?)?.toInt() ?? 0)));
  int get addOnTotal => draft.addOns.fold(0, (sum, addOn) => sum + ((addOn['cost'] as num?)?.toInt() ?? 0));
  int get grandTotal => menuTotal + serviceTotal + addOnTotal;

  @override
  Widget build(BuildContext context) => Column(children: [
        CpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(draft.name.isEmpty ? 'Untitled Event' : draft.name, style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)), Text('${draft.client} • ${draft.mobile}', style: const TextStyle(color: Cp.onVariant)), const Divider(), Wrap(spacing: 18, runSpacing: 12, children: [InfoTile(Icons.currency_rupee, 'Total Amount', money(grandTotal)), InfoTile(Icons.restaurant_menu, 'Menu', menuTotal > 0 ? money(menuTotal) : 'Not priced'), InfoTile(Icons.room_service, 'Services', serviceTotal > 0 ? money(serviceTotal) : 'None'), InfoTile(Icons.add_card, 'Add-ons', addOnTotal > 0 ? money(addOnTotal) : 'None'), InfoTile(Icons.calendar_today, 'Dates', '${draft.dates.length}'), InfoTile(Icons.restaurant_menu, 'Menu Slots', '${draft.dates.fold<int>(0, (sum, date) => sum + date.slots.length)}'), InfoTile(Icons.location_on, 'Venue', draft.venue.isEmpty ? 'Not set' : draft.venue)])])),
        const SizedBox(height: 12),
        CpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Add-ons', style: TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900))),
              TextButton.icon(onPressed: () => openAddOnSheet(context), icon: const Icon(Icons.add_circle), label: const Text('Add Add-on')),
            ]),
            const Text('Optional custom costs like service, decorations, printing, transport, etc.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 12),
            if (draft.addOns.isEmpty)
              const Text('No add-ons added.', style: TextStyle(color: Cp.onVariant, fontStyle: FontStyle.italic))
            else
              ...draft.addOns.map((addOn) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CpCard(
                      color: Cp.surfaceLow,
                      child: Row(children: [
                        const Icon(Icons.add_business, color: Cp.secondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(addOnLine(addOn), style: const TextStyle(fontWeight: FontWeight.w800))),
                        IconButton(onPressed: () => openAddOnSheet(context, addOn: addOn), icon: const Icon(Icons.edit, color: Cp.primary)),
                        IconButton(onPressed: () { draft.addOns.remove(addOn); onChanged(); }, icon: const Icon(Icons.delete, color: Cp.error)),
                      ]),
                    ),
                  )),
            Align(alignment: Alignment.centerRight, child: Text('Grand Total: ${money(grandTotal)}', style: const TextStyle(color: Cp.primary, fontSize: 16, fontWeight: FontWeight.w900))),
            if (draft.addOns.isNotEmpty) Align(alignment: Alignment.centerRight, child: Text('Add-ons Total: ${money(addOnTotal)}', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 12),
        CpCard(color: Cp.primaryContainer, child: const Text('Event will be saved to your account via API.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      ]);

  Future<void> openAddOnSheet(BuildContext context, {Map<String, dynamic>? addOn}) async {
    final result = await showAddOnSheet(context, addOn: addOn);
    if (result == null) return;
    if (addOn == null) {
      draft.addOns.add(result);
    } else {
      addOn
        ..clear()
        ..addAll(result);
    }
    onChanged();
  }
}

Future<Map<String, dynamic>?> showAddOnSheet(BuildContext context, {Map<String, dynamic>? addOn}) {
  final titleController = TextEditingController(text: addOn?['title']?.toString() ?? '');
  final costController = TextEditingController(text: ((addOn?['cost'] as num?)?.toInt() ?? 0) > 0 ? '${(addOn?['cost'] as num).toInt()}' : '');
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Text(addOn == null ? 'Add Add-on' : 'Edit Add-on', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const Text('Enter a custom title and cost. This amount is added to the event total.', style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 18),
            EditableInlineField(label: 'Add-on Title', controller: titleController),
            EditableInlineField(label: 'Cost', controller: costController),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Cp.secondaryContainer, foregroundColor: const Color(0xff694000)),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final cost = int.tryParse(costController.text.trim()) ?? 0;
                    if (title.isEmpty || cost <= 0) {
                      showCpSnack(context, 'Enter add-on title and cost');
                      return;
                    }
                    Navigator.pop(context, {'id': addOn?['id'] ?? 'addon_${DateTime.now().microsecondsSinceEpoch}', 'title': title, 'cost': cost});
                  },
                  child: const Text('Save Add-on', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  ).whenComplete(() {
    titleController.dispose();
    costController.dispose();
  });
}

class DashedAction extends StatelessWidget {
  const DashedAction({super.key, required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Cp.outlineVariant, width: 2, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Cp.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900))])),
      );
}

class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.active});
  final int active;
  @override
  Widget build(BuildContext context) {
    final labels = ['Details', 'Dates', 'Menu', 'Review'];
    return Row(children: List.generate(labels.length, (i) => Expanded(child: Column(children: [CircleAvatar(radius: 16, backgroundColor: i <= active ? Cp.primaryContainer : Cp.surfaceHigh, child: Text('${i + 1}', style: TextStyle(color: i <= active ? Colors.white : Cp.onVariant, fontWeight: FontWeight.w900))), const SizedBox(height: 4), Text(labels[i], style: TextStyle(color: i <= active ? Cp.primary : Cp.onVariant, fontSize: 11, fontWeight: FontWeight.w800))]))));
  }
}

class FormFieldBox extends StatefulWidget {
  const FormFieldBox({super.key, required this.label, required this.value, this.icon, this.height = 56, this.onChanged, this.inputFormatters});
  final String label, value;
  final IconData? icon;
  final double height;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<FormFieldBox> createState() => _FormFieldBoxState();
}

class _FormFieldBoxState extends State<FormFieldBox> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant FormFieldBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  TextInputType get keyboardType {
    final label = widget.label.toLowerCase();
    if (label.contains('phone') || label.contains('mobile') || label.contains('pax') || label.contains('price') || label.contains('amount') || label.contains('number')) {
      return TextInputType.phone;
    }
    if (label.contains('email')) return TextInputType.emailAddress;
    return widget.height > 70 ? TextInputType.multiline : TextInputType.text;
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.height > 70;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        constraints: BoxConstraints(minHeight: widget.height),
        padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
        decoration: BoxDecoration(border: Border.all(color: Cp.outline), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: widget.inputFormatters,
                onChanged: widget.onChanged,
                maxLines: multiline ? null : 1,
                minLines: multiline ? 3 : 1,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: const TextStyle(color: Cp.primary, fontSize: 13, fontWeight: FontWeight.w700),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.icon != null) Padding(padding: const EdgeInsets.only(left: 8, top: 8), child: Icon(widget.icon, color: Cp.outline)),
          ],
        ),
      ),
    );
  }
}

class ShareMenuTile extends StatelessWidget {
  const ShareMenuTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: Cp.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Cp.outlineVariant)),
            child: Row(children: [
              Icon(icon, color: Cp.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900))),
              const Icon(Icons.chevron_right, color: Cp.outline),
            ]),
          ),
        ),
      );
}

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key, required this.event, required this.api, required this.employees, required this.onEdit, required this.onEventUpdated, required this.onClose});
  final AppEvent? event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEdit;
  final ValueChanged<AppEvent> onEventUpdated;
  final VoidCallback onClose;

  Future<void> handleAction(BuildContext context, EventScreenAction action) async {
    final selectedEvent = event;
    if (selectedEvent == null) return;
    switch (action) {
      case EventScreenAction.assignEmployees:
        showCpSnack(context, 'Open the Team tab, then tap Assign.');
        break;
      case EventScreenAction.downloadQuotation:
        await downloadDocument(context, selectedEvent, 'quotation');
        break;
      case EventScreenAction.downloadInvoice:
        await downloadDocument(context, selectedEvent, 'invoice');
        break;
      case EventScreenAction.currentDayMenu:
        if (selectedEvent.dates.isEmpty) {
          showCpSnack(context, 'No event dates available for menu download');
        } else {
          await downloadDocument(context, selectedEvent, 'menu', dateId: selectedEvent.dates.first.id);
        }
        break;
      case EventScreenAction.allDaysMenu:
        await downloadDocument(context, selectedEvent, 'all-menus');
        break;
      case EventScreenAction.shareMenu:
        await showMenuShareSheet(context, selectedEvent);
        break;
      case EventScreenAction.deleteEvent:
        if (await confirmEventAction(context, 'Delete Event?', 'This will remove this event and all linked dates, menus, payments, and documents.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Event deleted');
          onClose();
        }
        break;
      case EventScreenAction.deleteDate:
        if (await confirmEventAction(context, 'Delete Date?', 'This will remove the selected event date and its menus.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Selected date deleted');
        }
        break;
      case EventScreenAction.deleteMenu:
        if (await confirmEventAction(context, 'Delete Menu?', 'This will remove the selected menu configuration for this event.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Selected menu deleted');
        }
        break;
    }
  }

  Future<void> downloadDocument(BuildContext context, AppEvent event, String type, {String? dateId}) async {
    try {
      final uri = await api.documentUri(event.id, type, dateId: dateId);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (!context.mounted) return;
      final label = switch (type) {
        'invoice' => 'Invoice',
        'quotation' => 'Quotation',
        'menu' => 'Menu',
        'all-menus' => 'All days menu',
        _ => 'Document',
      };
      showCpSnack(context, launched ? '$label download started' : 'Unable to start download');
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> showMenuShareSheet(BuildContext context, AppEvent event) async {
    try {
      final uri = await api.documentUri(event.id, 'all-menus');
      if (!context.mounted) return;
      final link = uri.toString();
      final message = 'CaterPro menu for ${event.name}: $link';
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
              const Text('Share Menu', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
              Text(event.name, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ShareMenuTile(
                icon: Icons.chat,
                label: 'WhatsApp',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
                },
              ),
              ShareMenuTile(
                icon: Icons.email,
                label: 'Email',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await launchUrl(Uri(scheme: 'mailto', queryParameters: {'subject': 'Menu - ${event.name}', 'body': message}), mode: LaunchMode.externalApplication);
                },
              ),
              ShareMenuTile(
                icon: Icons.sms,
                label: 'SMS',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await launchUrl(Uri(scheme: 'sms', queryParameters: {'body': message}), mode: LaunchMode.externalApplication);
                },
              ),
              ShareMenuTile(
                icon: Icons.link,
                label: 'Copy Link',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) showCpSnack(context, 'Menu link copied');
                },
              ),
              ShareMenuTile(
                icon: Icons.picture_as_pdf,
                label: 'Download PDF',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
                },
              ),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
          title: event?.name.isEmpty == false ? event!.name : 'Event Details',
          avatar: false,
          leading: IconButton(onPressed: onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)),
          actions: [
            if (event != null) IconButton(onPressed: () => onEdit(event!), icon: const Icon(Icons.edit, color: Cp.primary), tooltip: 'Edit event'),
            PopupMenuButton<EventScreenAction>(
              icon: const Icon(Icons.more_vert, color: Cp.onVariant),
              tooltip: 'Event menu',
              onSelected: (action) => handleAction(context, action),
              itemBuilder: (context) => [
                for (final action in eventScreenActions) ...[
                  if (action.value == EventScreenAction.deleteEvent) const PopupMenuDivider(),
                  PopupMenuItem<EventScreenAction>(
                    value: action.value,
                    child: Row(
                      children: [
                        Icon(action.icon, color: action.destructive ? Cp.error : Cp.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.label,
                            style: TextStyle(color: action.destructive ? Cp.error : Cp.onSurface, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: event == null
            ? const [EmptyStateCard(title: 'Select an event', message: 'Open an event from the event list to view details, payments, invoices, and quotations.')]
            : [EventDetailsContent(event: event!, api: api, employees: employees, onEventUpdated: onEventUpdated)],
      );
}

class EventDetailsContent extends StatefulWidget {
  const EventDetailsContent({super.key, required this.event, required this.api, required this.employees, required this.onEventUpdated});
  final AppEvent event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  State<EventDetailsContent> createState() => _EventDetailsContentState();
}

class _EventDetailsContentState extends State<EventDetailsContent> {
  int selectedTab = 0;
  static const tabs = ['Overview', 'Dates & Menus', 'Payments', 'Team'];
  static const tabIcons = [Icons.notes, Icons.restaurant_menu, Icons.payments, Icons.groups];

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final total = eventTotal(event);
    final paid = eventPaid(event);
    final balance = eventBalance(event);
    final progressValue = paid + eventSettledDiscount(event);
    final progress = total == 0 ? 0.0 : (progressValue / total).clamp(0.0, 1.0);
    return Column(children: [
      CpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Primary Contact', style: TextStyle(color: Cp.outline, fontSize: 10, fontWeight: FontWeight.w900)), Text(event.primaryClient.isEmpty ? event.mobile : event.primaryClient, style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)), Text(event.mobile, style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))])), if (eventIsIncomplete(event)) const Pill('DRAFT', color: Cp.secondaryFixed, textColor: Color(0xff663e00))]),
        const SizedBox(height: 16),
        Wrap(spacing: 18, runSpacing: 16, children: [InfoTile(Icons.calendar_today, 'Dates', event.dates.map((date) => date.date).join(', ')), InfoTile(Icons.location_on, 'Venue', event.venue.isEmpty ? 'Not set' : event.venue), const InfoTile(Icons.restaurant_menu, 'Menu Pax', 'Meal-wise'), InfoTile(Icons.pending_actions, 'Balance Due', money(balance), color: Cp.error)]),
        const SizedBox(height: 18),
        const Text('Payment Progress', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 12, color: Cp.primaryContainer, backgroundColor: Cp.surfaceHigh)),
      ])),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final selected = index == selectedTab;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: tabs[index],
                child: ChoiceChip(
                  selected: selected,
                  avatar: Icon(tabIcons[index], size: 18, color: selected ? Colors.white : Cp.primary),
                  label: selected ? Text(tabs[index]) : const SizedBox.shrink(),
                  selectedColor: Cp.primaryContainer,
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => selectedTab = index),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 16),
      EventDetailsTabContent(tab: selectedTab, event: event, api: widget.api, employees: widget.employees, onEventUpdated: widget.onEventUpdated),
    ]);
  }
}

class EventDetailsTabContent extends StatelessWidget {
  const EventDetailsTabContent({super.key, required this.tab, required this.event, required this.api, required this.employees, required this.onEventUpdated});
  final int tab;
  final AppEvent event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return event.dates.isEmpty
            ? const EmptyStateCard(title: 'No dates configured', message: 'Add event dates and menu types from the create flow.')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: event.dates.map((date) => EventDateMenuCard(date: date, onDownload: () async {
                  final uri = await api.documentUri(event.id, 'menu', dateId: date.id);
                  if (context.mounted) {
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
                    if (context.mounted) showCpSnack(context, launched ? 'Menu download started' : 'Unable to start download');
                  }
                })).toList());
      case 2:
        final total = eventTotal(event);
        final paid = eventPaid(event);
        final balance = eventBalance(event);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Payment Summary', style: TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Total: ${money(total)}'), Text('Paid: ${money(paid)}'), if (eventSettledDiscount(event) > 0) Text('Settlement Discount: ${money(eventSettledDiscount(event))}'), Text('Balance: ${money(balance)}', style: TextStyle(color: balance == 0 ? Cp.tertiary : Cp.error, fontWeight: FontWeight.w800))])),
          if (event.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...event.payments.map((payment) => CpCard(child: Row(children: [const Icon(Icons.payments, color: Cp.primary), const SizedBox(width: 12), Expanded(child: Text('${money(payment.amount)} • ${payment.mode}\n${payment.date}${payment.reference.isEmpty ? '' : ' • ${payment.reference}'}', style: const TextStyle(fontWeight: FontWeight.w800))), if (payment.settled) const Pill('Settled', color: Cp.tertiaryFixed, textColor: Color(0xff00210c))]))),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: balance == 0 ? null : () => showEventRecordPaymentSheet(context, event: event, api: api, onSaved: onEventUpdated),
              style: FilledButton.styleFrom(backgroundColor: Cp.secondaryContainer, foregroundColor: const Color(0xff694000), disabledBackgroundColor: Cp.surfaceHigh, disabledForegroundColor: Cp.onVariant),
              icon: Icon(balance == 0 ? Icons.check_circle : Icons.payments),
              label: Text(balance == 0 ? 'Payment Complete' : 'Record Payment', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]);
      case 3:
        return EventTeamSection(event: event, api: api, employees: employees, onEventUpdated: onEventUpdated);
      default:
        return MaterialDocumentsSection(event: event, api: api, onEventUpdated: onEventUpdated);
    }
  }
}

class EventTeamSection extends StatefulWidget {
  const EventTeamSection({super.key, required this.event, required this.api, required this.employees, required this.onEventUpdated});
  final AppEvent event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  State<EventTeamSection> createState() => _EventTeamSectionState();
}

class _EventTeamSectionState extends State<EventTeamSection> {
  late Future<List<AttendanceRecord>> attendanceFuture;

  @override
  void initState() {
    super.initState();
    attendanceFuture = widget.api.getAttendance(eventId: widget.event.id);
  }

  void reloadAttendance() {
    setState(() => attendanceFuture = widget.api.getAttendance(eventId: widget.event.id));
  }

  Future<void> assignEmployees() async {
    final selected = widget.event.employeeAssignments.map((item) => item.employeeId).toSet();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final draft = selected.toSet();
        var saving = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Assign Employees'),
            content: SizedBox(
              width: 520,
              child: widget.employees.isEmpty
                  ? const Text('Add employees in Settings > Employees first.')
                  : SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: widget.employees.map((employee) {
                        final checked = draft.contains(employee.id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${employee.designation} • ${money(employee.payPerDay)}/day'),
                          onChanged: (_) => setDialogState(() => checked ? draft.remove(employee.id) : draft.add(employee.id)),
                        );
                      }).toList()),
                    ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: widget.employees.isEmpty || saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final assignments = widget.employees.where((employee) => draft.contains(employee.id)).map((employee) => EventEmployeeAssignment(employeeId: employee.id, employeeName: employee.name, mobile: employee.mobile, designation: employee.designation, payPerDay: employee.payPerDay)).toList();
                          final saved = await widget.api.saveEventEmployeeAssignments(widget.event.id, assignments);
                          if (mounted) {
                            widget.onEventUpdated(saved);
                            reloadAttendance();
                            Navigator.of(this.context).pop();
                            showCpSnack(this.context, 'Employees assigned and marked present');
                          }
                        } catch (error) {
                          setDialogState(() => saving = false);
                          if (mounted) showCpSnack(this.context, error.toString().replaceFirst('Exception: ', ''));
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> markAttendance(Employee employee, String date, AttendanceRecord? existing) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AttendanceEditorDialog(
        employee: employee,
        event: widget.event,
        date: date,
        existing: existing,
        onSave: (record) async {
          await widget.api.saveAttendance(record);
          reloadAttendance();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assigned = widget.event.employeeAssignments.map(Employee.fromAssignment).toList();
    final dates = widget.event.dates.map((date) => date.date).where((date) => date.isNotEmpty).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('Assigned Employees', style: TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900))),
        OutlinedButton.icon(onPressed: assignEmployees, icon: const Icon(Icons.group_add), label: const Text('Assign')),
      ]),
      const SizedBox(height: 10),
      if (assigned.isEmpty)
        const EmptyStateCard(title: 'No employees assigned', message: 'Assign employees to this event to track attendance, salary, and reports later.')
      else
        FutureBuilder<List<AttendanceRecord>>(
          future: attendanceFuture,
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <AttendanceRecord>[];
            AttendanceRecord? findRecord(Employee employee, String date) => records.where((record) => record.employeeId == employee.id && record.date == date).firstOrNull;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...assigned.map((employee) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CpCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(backgroundColor: Cp.primaryFixed, child: Text(employee.name.isEmpty ? 'E' : employee.name[0].toUpperCase(), style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(employee.name, style: const TextStyle(color: Cp.primary, fontSize: 17, fontWeight: FontWeight.w900)),
                            Text('${employee.designation} • ${money(employee.payPerDay)}/day', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
                          ])),
                        ]),
                        const SizedBox(height: 12),
                        if (dates.isEmpty)
                          const Text('Add event dates before marking attendance.', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dates.map((date) {
                              final record = findRecord(employee, date);
                              final label = record == null ? 'Mark ${readableDateLabel(date)}' : '${readableDateLabel(date)} • ${record.status == 'present' ? 'Present full day' : record.status}${record.status == 'partial' ? ' ${record.hours}h' : ''}';
                              return ActionChip(
                                avatar: Icon(record == null ? Icons.radio_button_unchecked : Icons.check_circle, size: 18, color: record == null ? Cp.outline : Cp.tertiary),
                                label: Text(label),
                                onPressed: () => markAttendance(employee, date, record),
                              );
                            }).toList(),
                          ),
                      ]),
                    ),
                  )),
            ]);
          },
        ),
    ]);
  }
}

class AttendanceEditorDialog extends StatefulWidget {
  const AttendanceEditorDialog({super.key, required this.employee, required this.event, required this.date, this.existing, required this.onSave});
  final Employee employee;
  final AppEvent event;
  final String date;
  final AttendanceRecord? existing;
  final Future<void> Function(AttendanceRecord record) onSave;

  @override
  State<AttendanceEditorDialog> createState() => _AttendanceEditorDialogState();
}

class _AttendanceEditorDialogState extends State<AttendanceEditorDialog> {
  late String status = widget.existing?.status ?? 'present';
  late final hours = TextEditingController(text: widget.existing?.hours == null || widget.existing!.hours == 0 ? '' : '${widget.existing!.hours}');
  bool saving = false;

  @override
  void dispose() {
    hours.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsedHours = status == 'partial' ? double.tryParse(hours.text.trim()) ?? 0 : status == 'present' ? 8.0 : 0.0;
    if (status == 'partial' && parsedHours <= 0) {
      showCpSnack(context, 'Mention hours for partial attendance');
      return;
    }
    setState(() => saving = true);
    await widget.onSave(AttendanceRecord(
      id: widget.existing?.id ?? '',
      employeeId: widget.employee.id,
      employeeName: widget.employee.name,
      eventId: widget.event.id,
      eventName: widget.event.name,
      date: widget.date,
      status: status,
      hours: parsedHours,
      payPerDay: widget.employee.payPerDay,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Attendance • ${widget.employee.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'present', label: Text('Present')),
              ButtonSegment(value: 'absent', label: Text('Absent')),
              ButtonSegment(value: 'partial', label: Text('Partial')),
            ],
            selected: {status},
            onSelectionChanged: (value) => setState(() => status = value.first),
          ),
          if (status == 'partial') ...[
            const SizedBox(height: 12),
            TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hours worked')),
          ],
        ]),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save')),
        ],
      );
}

class MaterialDocumentsSection extends StatelessWidget {
  const MaterialDocumentsSection({super.key, required this.event, required this.api, required this.onEventUpdated});
  final AppEvent event;
  final ApiService api;
  final ValueChanged<AppEvent> onEventUpdated;

  Future<void> openEditor(BuildContext context, String type, {EventMaterialDocument? document}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => MaterialDocumentDialog(event: event, api: api, type: type, document: document, onSaved: onEventUpdated),
    );
  }

  Future<void> download(BuildContext context, EventMaterialDocument document) async {
    final uri = await api.materialDocumentPdfUri(event.id, document.id);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (context.mounted) showCpSnack(context, launched ? 'Material PDF download started' : 'Unable to start download');
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CpCard(color: Cp.primaryContainer, child: Text('Event Notes\n${event.notes.isEmpty ? 'No notes added.' : event.notes}', style: const TextStyle(color: Colors.white, height: 1.45, fontWeight: FontWeight.w700))),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('Event Material Documents', style: TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900))),
        Pill('${event.materialDocuments.length} lists'),
      ]),
      const SizedBox(height: 10),
      if (event.materialDocuments.isEmpty)
        const EmptyStateCard(title: 'No material documents', message: 'Create raw material, vegetables, or fruits lists for this event.')
      else
        ...event.materialDocuments.map((document) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                onTap: () => openEditor(context, document.type, document: document),
                child: Row(children: [
                  Icon(document.type == 'produce' ? Icons.eco : Icons.inventory_2, color: Cp.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(document.title.isEmpty ? document.typeLabel : document.title, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
                    Text('${document.typeLabel} • ${document.items.length} items', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
                  ])),
                  IconButton(onPressed: () => download(context, document), icon: const Icon(Icons.picture_as_pdf, color: Cp.primary), tooltip: 'Download PDF'),
                ]),
              ),
            )),
      const SizedBox(height: 6),
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(onPressed: () => openEditor(context, 'raw'), icon: const Icon(Icons.inventory_2), label: const Text('Create Raw Material List')),
        OutlinedButton.icon(onPressed: () => openEditor(context, 'produce'), icon: const Icon(Icons.eco), label: const Text('Create Vegetables & Fruits List')),
      ]),
    ]);
  }
}

class MaterialDocumentDialog extends StatefulWidget {
  const MaterialDocumentDialog({super.key, required this.event, required this.api, required this.type, this.document, required this.onSaved});
  final AppEvent event;
  final ApiService api;
  final String type;
  final EventMaterialDocument? document;
  final ValueChanged<AppEvent> onSaved;

  @override
  State<MaterialDocumentDialog> createState() => _MaterialDocumentDialogState();
}

class _MaterialDocumentDialogState extends State<MaterialDocumentDialog> {
  final titleController = TextEditingController();
  final queryController = TextEditingController();
  final items = <RawMaterialItem>[];
  final quantityControllers = <String, TextEditingController>{};
  final unitControllers = <String, TextEditingController>{};
  bool loading = true;
  bool saving = false;
  String query = '';
  String? error;

  String get typeLabel => widget.type == 'produce' ? 'Vegetables & Fruits' : 'Raw Materials';

  @override
  void initState() {
    super.initState();
    final count = widget.event.materialDocuments.where((document) => document.type == widget.type).length + 1;
    titleController.text = widget.document?.title ?? '$typeLabel List $count';
    loadCatalog();
  }

  @override
  void dispose() {
    titleController.dispose();
    queryController.dispose();
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in unitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadCatalog() async {
    try {
      final loaded = widget.type == 'produce' ? await widget.api.getProduceItems() : await widget.api.getRawMaterials();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
        for (final item in items) {
          quantityControllers[item.id] = TextEditingController();
          unitControllers[item.id] = TextEditingController(text: item.unit);
        }
        for (final line in widget.document?.items ?? const <EventMaterialLine>[]) {
          quantityControllers[line.itemId]?.text = line.quantity;
          unitControllers[line.itemId]?.text = line.unit;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    final filtered = items.where((item) {
      final text = '${item.id} ${item.name} ${item.category}'.toLowerCase();
      return normalized.isEmpty || text.contains(normalized);
    }).toList();
    filtered.sort((a, b) {
      final aSelected = (quantityControllers[a.id]?.text.trim().isNotEmpty ?? false) ? 0 : 1;
      final bSelected = (quantityControllers[b.id]?.text.trim().isNotEmpty ?? false) ? 0 : 1;
      if (aSelected != bSelected) return aSelected.compareTo(bSelected);
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  Future<void> save() async {
    final lines = <EventMaterialLine>[];
    for (final item in items) {
      final quantity = quantityControllers[item.id]?.text.trim() ?? '';
      if (quantity.isEmpty) continue;
      lines.add(EventMaterialLine(itemId: item.id, name: item.name, category: item.category, quantity: quantity, unit: unitControllers[item.id]?.text.trim() ?? item.unit));
    }
    if (lines.isEmpty) {
      setState(() => error = 'Enter quantity/count for at least one item.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final savedEvent = await widget.api.saveMaterialDocument(widget.event.id, EventMaterialDocument(id: widget.document?.id ?? '', type: widget.type, title: titleController.text.trim(), items: lines));
      widget.onSaved(savedEvent);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Cp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 820, maxHeight: MediaQuery.of(context).size.height * .86),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text(widget.document == null ? 'Create $typeLabel List' : 'Edit $typeLabel List', style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              const SizedBox(height: 10),
              EditableInlineField(label: 'Document Title', controller: titleController),
              TextField(
                controller: queryController,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search items', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: Cp.primary))
                    : ListView.separated(
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          return CpCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Cp.primary))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: quantityControllers[item.id], decoration: const InputDecoration(labelText: 'Count/Qty', isDense: true), onChanged: (_) => setState(() {}))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: unitControllers[item.id], decoration: const InputDecoration(labelText: 'Unit', isDense: true))),
                            ]),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(height: 52, child: FilledButton.icon(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save List', style: const TextStyle(fontWeight: FontWeight.w900)))),
            ]),
          ),
        ),
      );
}

class EventDateMenuCard extends StatelessWidget {
  const EventDateMenuCard({super.key, required this.date, required this.onDownload});
  final AppEventDate date;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          child: Row(
            children: [
              Container(
                width: 54,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Cp.primaryFixed, borderRadius: BorderRadius.circular(10)),
                child: Text(date.date.split('-').skip(1).join('\n'), textAlign: TextAlign.center, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900, height: 1.1)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date.label.isEmpty ? date.date : date.label, style: const TextStyle(color: Cp.primary, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(date.menuSlots.isEmpty ? 'No menu slots' : date.menuSlots.map((slot) => '${slot.type} • ${slot.pax} pax • ${money(slot.pricePerPax)}/pax').join('\n'), style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDownload,
                icon: const Icon(Icons.picture_as_pdf, color: Cp.primary),
                tooltip: 'Download menu PDF',
              ),
            ],
          ),
        ),
      );
}

class DocumentRow extends StatelessWidget {
  const DocumentRow({super.key, required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(child: Row(children: [const Icon(Icons.description, color: Cp.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: Cp.onVariant))])), const Icon(Icons.download, color: Cp.primary)])),
      );
}

class InfoTile extends StatelessWidget {
  const InfoTile(this.icon, this.label, this.value, {super.key, this.color = Cp.primary});
  final IconData icon;
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 150, child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Cp.outline, fontWeight: FontWeight.w900)), Text(value, style: TextStyle(color: color == Cp.error ? color : Cp.onSurface, fontWeight: FontWeight.w800))]))]));
}

class MenuMasterItem {
  const MenuMasterItem({required this.id, required this.english, required this.kannada, required this.category, required this.meals, required this.veg});
  final String id;
  final String english;
  final String kannada;
  final String category;
  final String meals;
  final bool veg;

  String get title => '$kannada/$english';

  factory MenuMasterItem.fromJson(Map<String, dynamic> json) {
    final mealsValue = json['meals'];
    final mealsText = mealsValue is List ? mealsValue.map((item) => item.toString()).join(', ') : mealsValue?.toString() ?? '';
    return MenuMasterItem(
      id: json['id']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      kannada: json['kannada']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      meals: mealsText,
      veg: json['veg'] == true,
    );
  }
}

MenuMasterItem? menuItemById(String id) {
  for (final item in MenuMasterScreen.menuItems) {
    if (item.id == id) return item;
  }
  return null;
}

int selectedOrder(String id, Set<String> selectedIds) {
  var index = 0;
  for (final selectedId in selectedIds) {
    if (selectedId == id) return index;
    index++;
  }
  return -1;
}

class MenuMasterScreen extends StatefulWidget {
  const MenuMasterScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  static final List<MenuMasterItem> menuItems = [
  ];

  @override
  State<MenuMasterScreen> createState() => _MenuMasterScreenState();
}

class _MenuMasterScreenState extends State<MenuMasterScreen> {
  String query = '';
  String selectedMealFilter = 'All';
  bool vegOnly = false;

  List<MenuMasterItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return MenuMasterScreen.menuItems.where((item) {
      final text = '${item.id} ${item.english} ${item.kannada} ${item.category} ${item.meals}'.toLowerCase();
      final matchesSearch = normalized.isEmpty || text.contains(normalized);
      final matchesMeal = selectedMealFilter == 'All' || item.meals.split(',').map((meal) => meal.trim()).contains(selectedMealFilter);
      final matchesVeg = !vegOnly || item.veg;
      return matchesSearch && matchesMeal && matchesVeg;
    }).toList();
  }

  void upsertMenuItem(MenuMasterItem item) {
    setState(() {
      final index = MenuMasterScreen.menuItems.indexWhere((existing) => existing.id == item.id);
      if (index == -1) {
        MenuMasterScreen.menuItems.add(item);
      } else {
        MenuMasterScreen.menuItems[index] = item;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(topBar: TopBar(title: 'Menu Master', avatar: false, leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)), actions: [IconButton(onPressed: () => showMenuItemEditor(context, onSave: upsertMenuItem), icon: const Icon(Icons.add))]), children: [
        CpCard(color: Cp.primaryFixed, child: const Row(children: [Icon(Icons.public, color: Cp.primary), SizedBox(width: 10), Expanded(child: Text('Universal menu catalog. Add/edit only. Every user can access these items.', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)))])),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search menu items', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...['All', 'Breakfast', 'Juice', 'Lunch', 'Snack', 'Dinner'].map((filter) {
                final selected = selectedMealFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => selectedMealFilter = filter),
                    child: Pill(filter, color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => vegOnly = !vegOnly),
                  child: Pill('Veg Only', color: vegOnly ? Cp.tertiaryContainer : Cp.surfaceHigh, textColor: vegOnly ? Colors.white : Cp.onVariant, icon: vegOnly ? Icons.check : Icons.eco),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...visibleItems.map((item) => MenuItemCard(item: item, onEdit: () => showMenuItemEditor(context, item: item, onSave: upsertMenuItem))),
        const SizedBox(height: 18),
        CpCard(color: Cp.primaryContainer, child: Text('Universal Menu Items\n${MenuMasterScreen.menuItems.length} Items', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
      ]);
}

class MenuItemCard extends StatefulWidget {
  const MenuItemCard({super.key, required this.item, required this.onEdit});
  final MenuMasterItem item;
  final VoidCallback onEdit;

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool active = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          onTap: widget.onEdit,
          child: Row(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: widget.item.veg ? Cp.tertiaryFixed.withValues(alpha: .3) : Cp.errorContainer, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.restaurant, color: widget.item.veg ? Cp.tertiary : Cp.error)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.item.id, style: const TextStyle(color: Cp.outline, fontSize: 11, fontWeight: FontWeight.w900)),
                Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.item.veg ? Colors.green : Colors.red, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(widget.item.title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
                Text('English: ${widget.item.english}', style: const TextStyle(color: Cp.onVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('Kannada: ${widget.item.kannada}', style: const TextStyle(color: Cp.onVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${widget.item.category} • ${widget.item.meals}', style: const TextStyle(color: Cp.onVariant)),
              ]),
            ),
            IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit, color: Cp.primary)),
            Switch(value: active, activeThumbColor: Cp.primaryContainer, onChanged: (value) => setState(() => active = value)),
          ]),
        ),
      );
}

void showMenuItemEditor(BuildContext context, {MenuMasterItem? item, required ValueChanged<MenuMasterItem> onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MenuItemEditorSheet(item: item, onSave: onSave),
  );
}

class MenuItemEditorSheet extends StatefulWidget {
  const MenuItemEditorSheet({super.key, this.item, required this.onSave});
  final MenuMasterItem? item;
  final ValueChanged<MenuMasterItem> onSave;

  @override
  State<MenuItemEditorSheet> createState() => _MenuItemEditorSheetState();
}

class _MenuItemEditorSheetState extends State<MenuItemEditorSheet> {
  static const categoryOptions = ['Starter', 'Main Course', 'Dessert', 'South Indian', 'Beverage', 'Snack', 'Other'];
  static const mealOptions = ['Breakfast', 'Lunch', 'Dinner', 'Other', 'Snack', 'Juice'];
  late final id = TextEditingController(text: widget.item?.id ?? 'MNU-${(MenuMasterScreen.menuItems.length + 1).toString().padLeft(3, '0')}');
  late final english = TextEditingController(text: widget.item?.english ?? '');
  late final kannada = TextEditingController(text: widget.item?.kannada ?? '');
  late String category = categoryOptions.contains(widget.item?.category) ? widget.item!.category : categoryOptions.first;
  late Set<String> selectedMeals = {
    if (widget.item != null)
      ...widget.item!.meals.split(',').map((meal) => meal.trim()).where((meal) => mealOptions.contains(meal)),
  };
  late bool veg = widget.item?.veg ?? true;
  String? error;

  @override
  void dispose() {
    id.dispose();
    english.dispose();
    kannada.dispose();
    super.dispose();
  }

  void save() {
    if (id.text.trim().isEmpty || english.text.trim().isEmpty || kannada.text.trim().isEmpty || selectedMeals.isEmpty) {
      setState(() => error = 'Fill ID, English, Kannada, Category, and at least one Meal.');
      return;
    }
    final meals = mealOptions.where(selectedMeals.contains).join(', ');
    widget.onSave(MenuMasterItem(id: id.text.trim(), english: english.text.trim(), kannada: kannada.text.trim(), category: category, meals: meals, veg: veg));
    Navigator.pop(context);
  }

  Future<void> pickMeals() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MealCheckboxSheet(options: mealOptions, selected: selectedMeals),
    );
    if (result != null) setState(() => selectedMeals = result);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
              Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('Universal item, available to every user.', style: TextStyle(color: Cp.onVariant)),
              const SizedBox(height: 16),
              EditableInlineField(label: 'ID', controller: id),
              Row(children: [Expanded(child: EditableInlineField(label: 'English', controller: english)), const SizedBox(width: 12), Expanded(child: EditableInlineField(label: 'Kannada', controller: kannada))]),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: categoryOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => category = value ?? category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: pickMeals,
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Meals', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: Row(children: [
                        Expanded(child: Text(selectedMeals.isEmpty ? 'Select meals' : mealOptions.where(selectedMeals.contains).join(', '), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.arrow_drop_down, color: Cp.primary),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: veg, activeThumbColor: Cp.primary, onChanged: (value) => setState(() => veg = value), title: const Text('Vegetarian', style: TextStyle(fontWeight: FontWeight.w900))),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: save, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: const Icon(Icons.save), label: const Text('Save Menu Item', style: TextStyle(fontWeight: FontWeight.w900)))),
            ]),
          ),
        ),
      );
}

class MealCheckboxSheet extends StatefulWidget {
  const MealCheckboxSheet({super.key, required this.options, required this.selected});
  final List<String> options;
  final Set<String> selected;

  @override
  State<MealCheckboxSheet> createState() => _MealCheckboxSheetState();
}

class _MealCheckboxSheetState extends State<MealCheckboxSheet> {
  late final Set<String> selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .78),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
          const Text('Select Meals', style: TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.options.map((meal) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(meal),
                    activeColor: Cp.primary,
                    onChanged: (value) => setState(() => value == true ? selected.add(meal) : selected.remove(meal)),
                    title: Text(meal, style: const TextStyle(fontWeight: FontWeight.w800)),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer),
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Apply Meals', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

class CustomMenuScreen extends StatefulWidget {
  const CustomMenuScreen({super.key, required this.onClose, required this.customMenus, required this.onSave});
  final VoidCallback onClose;
  final List<CustomMenu> customMenus;
  final Future<void> Function(CustomMenu menu) onSave;

  static const types = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Juice', 'Other'];

  @override
  State<CustomMenuScreen> createState() => _CustomMenuScreenState();
}

class _CustomMenuScreenState extends State<CustomMenuScreen> {
  int selectedTypeIndex = 0;
  bool saving = false;

  String get selectedType => CustomMenuScreen.types[selectedTypeIndex];

  List<CustomMenu> get visibleMenus {
    return widget.customMenus.where((menu) => menu.type == selectedType).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> openEditor([CustomMenu? menu]) async {
    final saved = await showModalBottomSheet<CustomMenu>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomMenuEditorSheet(type: selectedType, menu: menu),
    );
    if (saved == null) return;
    setState(() => saving = true);
    try {
      await widget.onSave(saved);
      if (mounted) showCpSnack(context, 'Custom menu saved');
    } catch (e) {
      if (mounted) showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      topBar: TopBar(
        title: 'Custom Menus',
        avatar: false,
        leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)),
        actions: [IconButton(onPressed: saving ? null : () => openEditor(), icon: const Icon(Icons.add, color: Cp.primary))],
      ),
      children: [
        CpCard(color: Cp.primaryFixed, child: const Row(children: [Icon(Icons.fact_check, color: Cp.primary), SizedBox(width: 10), Expanded(child: Text('Ready made menu sets are saved under your user and can be applied during event menu selection.', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)))])),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(CustomMenuScreen.types.length, (index) {
              final type = CustomMenuScreen.types[index];
              final selected = index == selectedTypeIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => selectedTypeIndex = index),
                  child: Pill(type, color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        DashedAction(label: 'Add $selectedType Custom Menu', icon: Icons.add_circle, onTap: saving ? null : () => openEditor()),
        const SizedBox(height: 14),
        if (visibleMenus.isEmpty)
          EmptyStateCard(title: 'No $selectedType custom menus', message: 'Tap + to create a ready made $selectedType menu.')
        else
          ...visibleMenus.map((menu) {
            final names = menu.itemIds.map((id) => menuItemById(id)?.english ?? id).take(5).join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                onTap: () => openEditor(menu),
                child: Row(children: [
                  const Icon(Icons.playlist_add_check, color: Cp.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(menu.name, style: const TextStyle(color: Cp.primary, fontSize: 17, fontWeight: FontWeight.w900)),
                      Text('${menu.itemIds.length} items${names.isEmpty ? '' : ' • $names'}', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const Icon(Icons.edit, color: Cp.primary),
                ]),
              ),
            );
          }),
      ],
    );
  }
}

class CustomMenuEditorSheet extends StatefulWidget {
  const CustomMenuEditorSheet({super.key, required this.type, this.menu});
  final String type;
  final CustomMenu? menu;

  @override
  State<CustomMenuEditorSheet> createState() => _CustomMenuEditorSheetState();
}

class _CustomMenuEditorSheetState extends State<CustomMenuEditorSheet> {
  late final name = TextEditingController(text: widget.menu?.name ?? '');
  late Set<String> selectedIds = {...?widget.menu?.itemIds};
  String query = '';
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  List<MenuMasterItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return MenuMasterScreen.menuItems.where((item) {
      final mealList = item.meals.split(',').map((meal) => meal.trim()).toSet();
      final typeMatches = widget.type == 'Other' ? mealList.contains('Other') || mealList.isEmpty : mealList.contains(widget.type);
      final text = '${item.id} ${item.title} ${item.category} ${item.meals}'.toLowerCase();
      return typeMatches && (normalized.isEmpty || text.contains(normalized));
    }).toList()
      ..sort((a, b) {
        final aOrder = selectedOrder(a.id, selectedIds);
        final bOrder = selectedOrder(b.id, selectedIds);
        if (aOrder != -1 && bOrder != -1) return aOrder.compareTo(bOrder);
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0).compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.english.compareTo(b.english);
      });
  }

  void save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = 'Menu name is required.');
      return;
    }
    if (selectedIds.isEmpty) {
      setState(() => error = 'Select at least one menu item.');
      return;
    }
    Navigator.pop(context, CustomMenu(id: widget.menu?.id ?? '', name: trimmed, type: widget.type, itemIds: selectedIds));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Cp.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
          Text(widget.menu == null ? 'Add ${widget.type} Custom Menu' : 'Edit ${widget.type} Custom Menu', style: const TextStyle(color: Cp.primary, fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('Pick the items that should be selected together.', style: TextStyle(color: Cp.onVariant)),
          const SizedBox(height: 14),
          EditableInlineField(label: 'Menu Name', controller: name),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search ${widget.type} items', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onChanged: (value) => setState(() => query = value),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: visibleItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final selected = selectedIds.contains(item.id);
                return CpCard(
                  color: selected ? Cp.primaryFixed : Cp.card,
                  onTap: () => setState(() => selected ? selectedIds.remove(item.id) : selectedIds.add(item.id)),
                  child: Row(children: [
                    Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Cp.primary : Cp.outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${item.title}\n${item.id} • ${item.category}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: save, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: const Icon(Icons.save), label: const Text('Save Custom Menu', style: TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }
}

class RawMaterialItem {
  const RawMaterialItem({required this.id, required this.name, required this.category, required this.unit});
  final String id;
  final String name;
  final String category;
  final String unit;

  factory RawMaterialItem.fromJson(Map<String, dynamic> json) => RawMaterialItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category, 'unit': unit};
}

class RawMaterialScreen extends StatefulWidget {
  const RawMaterialScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends State<RawMaterialScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRawMaterials();
  }

  Future<void> loadRawMaterials() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getRawMaterials();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get categories {
    final values = items.map((item) => item.category).where((category) => category.isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final text = '${item.id} ${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return matchesCategory && (normalized.isEmpty || text.contains(normalized));
    }).toList();
  }

  Future<void> upsertRawMaterial(RawMaterialItem item) async {
    try {
      final saved = await api.saveRawMaterial(item);
      setState(() {
      final index = items.indexWhere((existing) => existing.id == saved.id);
      if (index == -1) {
        items.add(saved);
      } else {
        items[index] = saved;
      }
      });
      if (mounted) showCpSnack(context, 'Raw material saved');
    } catch (e) {
      if (mounted) showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ScreenFrame(
            bottomPadding: 92,
            topBar: TopBar(title: 'Raw Materials', avatar: false, leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary))),
            children: [
              CpCard(color: Cp.primaryFixed, child: const Row(children: [Icon(Icons.public, color: Cp.primary), SizedBox(width: 10), Expanded(child: Text('Universal raw material catalog. Add/edit only. Every user can access these items.', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)))])),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search raw materials', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              if (error != null) ...[CpCard(color: Cp.errorContainer, child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))), const SizedBox(height: 12)],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => selectedCategory = category),
                        child: Pill(category, color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (loading) const Center(child: CircularProgressIndicator(color: Cp.primary)),
              if (!loading && visibleItems.isEmpty) const EmptyStateCard(title: 'No raw materials', message: 'No items match this search.'),
              if (!loading) ...visibleItems.map((item) => RawMaterialCard(item: item, onEdit: () => showRawMaterialEditor(context, item: item, onSave: (value) { upsertRawMaterial(value); }))),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'addRawMaterial',
              backgroundColor: Cp.secondaryContainer,
              foregroundColor: const Color(0xff694000),
              onPressed: () => showRawMaterialEditor(context, onSave: (value) { upsertRawMaterial(value); }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}

class ProduceItemScreen extends StatefulWidget {
  const ProduceItemScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<ProduceItemScreen> createState() => _ProduceItemScreenState();
}

class _ProduceItemScreenState extends State<ProduceItemScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getProduceItems();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get categories {
    final values = items.map((item) => item.category).where((category) => category.isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final text = '${item.id} ${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return matchesCategory && (normalized.isEmpty || text.contains(normalized));
    }).toList();
  }

  Future<void> upsertItem(RawMaterialItem item) async {
    try {
      final saved = await api.saveProduceItem(item);
      setState(() {
        final index = items.indexWhere((existing) => existing.id == saved.id);
        if (index == -1) {
          items.add(saved);
        } else {
          items[index] = saved;
        }
      });
      if (mounted) showCpSnack(context, 'Vegetable/fruit saved');
    } catch (e) {
      if (mounted) showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ScreenFrame(
            bottomPadding: 92,
            topBar: TopBar(title: 'Vegetables & Fruits', avatar: false, leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary))),
            children: [
              CpCard(color: Cp.primaryFixed, child: const Row(children: [Icon(Icons.public, color: Cp.primary), SizedBox(width: 10), Expanded(child: Text('Universal vegetables and fruits catalog in Kannada. Add/edit only. Every user can access these items.', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w800)))])),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search vegetables and fruits', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              if (error != null) ...[CpCard(color: Cp.errorContainer, child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))), const SizedBox(height: 12)],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => selectedCategory = category),
                        child: Pill(category, color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (loading) const Center(child: CircularProgressIndicator(color: Cp.primary)),
              if (!loading && visibleItems.isEmpty) const EmptyStateCard(title: 'No vegetables/fruits', message: 'No items match this search.'),
              if (!loading) ...visibleItems.map((item) => RawMaterialCard(item: item, onEdit: () => showRawMaterialEditor(context, item: item, noun: 'Vegetable/Fruit', onSave: (value) { upsertItem(value); }))),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'addProduceItem',
              backgroundColor: Cp.secondaryContainer,
              foregroundColor: const Color(0xff694000),
              onPressed: () => showRawMaterialEditor(context, noun: 'Vegetable/Fruit', onSave: (value) { upsertItem(value); }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}

class RawMaterialCard extends StatelessWidget {
  const RawMaterialCard({super.key, required this.item, required this.onEdit});
  final RawMaterialItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          onTap: onEdit,
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: Cp.primaryFixed, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.inventory_2, color: Cp.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(color: Cp.primary, fontSize: 17, fontWeight: FontWeight.w900)), Text('${item.id} • ${item.category}', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700))])),
            Pill(item.unit),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Cp.primary)),
          ]),
        ),
      );
}

void showRawMaterialEditor(BuildContext context, {RawMaterialItem? item, required ValueChanged<RawMaterialItem> onSave, String noun = 'Raw Material'}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => RawMaterialEditorSheet(item: item, onSave: onSave, noun: noun),
  );
}

class RawMaterialEditorSheet extends StatefulWidget {
  const RawMaterialEditorSheet({super.key, this.item, required this.onSave, required this.noun});
  final RawMaterialItem? item;
  final ValueChanged<RawMaterialItem> onSave;
  final String noun;

  @override
  State<RawMaterialEditorSheet> createState() => _RawMaterialEditorSheetState();
}

class _RawMaterialEditorSheetState extends State<RawMaterialEditorSheet> {
  late final id = TextEditingController(text: widget.item?.id ?? '');
  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final category = TextEditingController(text: widget.item?.category ?? '');
  late final unit = TextEditingController(text: widget.item?.unit ?? '');
  String? error;

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    category.dispose();
    unit.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty || category.text.trim().isEmpty || unit.text.trim().isEmpty) {
      setState(() => error = 'Fill Name, Category, and Unit.');
      return;
    }
    widget.onSave(RawMaterialItem(id: id.text.trim(), name: name.text.trim(), category: category.text.trim(), unit: unit.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
              Text(widget.item == null ? 'Add ${widget.noun}' : 'Edit ${widget.noun}', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('Universal item, available to every user.', style: TextStyle(color: Cp.onVariant)),
              const SizedBox(height: 16),
              EditableInlineField(label: 'ID', controller: id),
              EditableInlineField(label: 'Name', controller: name),
              Row(children: [Expanded(child: EditableInlineField(label: 'Category', controller: category)), const SizedBox(width: 12), Expanded(child: EditableInlineField(label: 'Unit', controller: unit))]),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: save, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: const Icon(Icons.save), label: Text('Save ${widget.noun}', style: const TextStyle(fontWeight: FontWeight.w900)))),
            ]),
          ),
        ),
      );
}

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key, required this.api, required this.employees, required this.onSave, required this.onDelete, required this.onClose});
  final ApiService api;
  final List<Employee> employees;
  final Future<void> Function(Employee employee) onSave;
  final Future<void> Function(Employee employee) onDelete;
  final VoidCallback onClose;

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final search = TextEditingController();
  String selectedFilter = 'All';
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<String> get filters {
    final designations = widget.employees.map((employee) => employee.designation).toSet().toList()..sort();
    return ['All', ...designations];
  }

  List<Employee> get visibleEmployees {
    final normalizedQuery = query.trim().toLowerCase();
    return widget.employees.where((employee) {
      final matchesFilter = selectedFilter == 'All' || employee.designation == selectedFilter;
      final text = '${employee.name} ${employee.mobile} ${employee.designation}'.toLowerCase();
      return matchesFilter && (normalizedQuery.isEmpty || text.contains(normalizedQuery));
    }).toList();
  }

  Future<void> saveEmployee(Employee employee) async {
    await widget.onSave(employee);
    if (mounted) {
      setState(() => selectedFilter = 'All');
      showCpSnack(context, '${employee.name} saved');
    }
  }

  Future<void> deleteEmployee(Employee employee) async {
    await widget.onDelete(employee);
    if (mounted) showCpSnack(context, '${employee.name} deleted');
  }

  Future<void> openAttendanceSheet() async {
    await showDialog<void>(context: context, builder: (context) => AttendanceSheetDialog(api: widget.api, employees: widget.employees));
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleEmployees;
    return Stack(
      children: [
        ScreenFrame(
          bottomPadding: 92,
          topBar: TopBar(
            title: 'Employees',
            avatar: false,
            leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)),
            actions: [IconButton(onPressed: openAttendanceSheet, icon: const Icon(Icons.calendar_month, color: Cp.primary), tooltip: 'Attendance sheet')],
          ),
          children: [
            TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Cp.primary),
                hintText: 'Search employees',
                filled: true,
                fillColor: Cp.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Cp.outlineVariant.withValues(alpha: .5))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Cp.outlineVariant.withValues(alpha: .5))),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final selected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => selectedFilter = filter),
                      child: Pill(filter, color: selected ? Cp.primaryContainer : Cp.surfaceHigh, textColor: selected ? Colors.white : Cp.onVariant, icon: selected ? Icons.check : null),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: Text('${visible.length} employees', style: const TextStyle(color: Cp.primary, fontSize: 20, fontWeight: FontWeight.w900))), Pill(selectedFilter)]),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              CpCard(color: Cp.surfaceLow, child: const Text('No employees match this search/filter.', style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w800)))
            else
              ...visible.map((employee) => EmployeeCard(employee: employee, onTap: () => showEmployeeEditor(context, employee: employee, onSave: saveEmployee), onDelete: () => deleteEmployee(employee))),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'addEmployee',
            backgroundColor: Cp.secondaryContainer,
            foregroundColor: const Color(0xff694000),
            onPressed: () => showEmployeeEditor(context, onSave: saveEmployee),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee, required this.onTap, required this.onDelete});
  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Row(children: [
          CircleAvatar(radius: 24, backgroundColor: Cp.primaryFixed, child: Text(employee.name.split(' ').map((part) => part[0]).take(2).join(), style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.name, style: const TextStyle(color: Cp.primary, fontSize: 17, fontWeight: FontWeight.w900)),
              Text('${employee.designation} • Age ${employee.age}', style: const TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
              Text(employee.mobile, style: const TextStyle(color: Cp.onVariant)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Pay/Day', style: TextStyle(color: Cp.outline, fontSize: 10, fontWeight: FontWeight.w900)),
            Text(money(employee.payPerDay), style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
            IconButton(visualDensity: VisualDensity.compact, onPressed: onDelete, icon: const Icon(Icons.delete, color: Cp.error), tooltip: 'Delete employee'),
          ]),
        ]),
      ),
    );
  }
}

void showEmployeeEditor(BuildContext context, {Employee? employee, required Future<void> Function(Employee employee) onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EmployeeEditorSheet(employee: employee, onSave: onSave),
  );
}

class EmployeeEditorSheet extends StatefulWidget {
  const EmployeeEditorSheet({super.key, this.employee, required this.onSave});
  final Employee? employee;
  final Future<void> Function(Employee employee) onSave;

  @override
  State<EmployeeEditorSheet> createState() => _EmployeeEditorSheetState();
}

class _EmployeeEditorSheetState extends State<EmployeeEditorSheet> {
  late final name = TextEditingController(text: widget.employee?.name ?? '');
  late final age = TextEditingController(text: widget.employee?.age == null || widget.employee!.age == 0 ? '' : '${widget.employee!.age}');
  late final mobile = TextEditingController(text: widget.employee?.mobile ?? '');
  late final designation = TextEditingController(text: widget.employee?.designation ?? '');
  late final payPerDay = TextEditingController(text: widget.employee?.payPerDay == null || widget.employee!.payPerDay == 0 ? '' : '${widget.employee!.payPerDay}');
  String? error;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    mobile.dispose();
    designation.dispose();
    payPerDay.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsedAge = int.tryParse(age.text.trim());
    final parsedPay = int.tryParse(payPerDay.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final cleanMobile = normalizeMobileText(mobile.text);
    if (name.text.trim().isEmpty || parsedAge == null || cleanMobile.isEmpty || designation.text.trim().isEmpty || parsedPay == null) {
      setState(() => error = 'Fill Name, Age, Mobile, Designation, and Pay/Day.');
      return;
    }
    if (parsedAge < 16 || parsedAge > 100) {
      setState(() => error = 'Age must be between 16 and 100.');
      return;
    }
    if (cleanMobile.length != 10) {
      setState(() => error = 'Mobile number must be 10 digits.');
      return;
    }
    if (parsedPay <= 0) {
      setState(() => error = 'Pay/Day must be more than zero.');
      return;
    }
    setState(() => saving = true);
    await widget.onSave(Employee(id: widget.employee?.id ?? '', name: name.text.trim(), age: parsedAge, mobile: cleanMobile, designation: designation.text.trim(), payPerDay: parsedPay));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Cp.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Cp.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            Text(widget.employee == null ? 'Add Employee' : 'Edit Employee', style: const TextStyle(color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            EditableInlineField(label: 'Name', controller: name),
            Row(children: [Expanded(child: EditableInlineField(label: 'Age', controller: age, keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: EditableInlineField(label: 'Pay/Day', controller: payPerDay, keyboardType: TextInputType.number))]),
            EditableInlineField(label: 'Mobile', controller: mobile, keyboardType: TextInputType.phone, inputFormatters: mobileInputFormatters),
            EditableInlineField(label: 'Designation', controller: designation),
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))),
            SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: Cp.primaryContainer), icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save Employee', style: const TextStyle(fontWeight: FontWeight.w900)))),
          ]),
        ),
      ),
    );
  }
}

class AttendanceSheetDialog extends StatefulWidget {
  const AttendanceSheetDialog({super.key, required this.api, required this.employees});
  final ApiService api;
  final List<Employee> employees;

  @override
  State<AttendanceSheetDialog> createState() => _AttendanceSheetDialogState();
}

class _AttendanceSheetDialogState extends State<AttendanceSheetDialog> {
  late String month = DateTime.now().toIso8601String().substring(0, 7);
  late Future<List<AttendanceRecord>> recordsFuture = widget.api.getAttendance(month: month);

  void changeMonth(int delta) {
    final parts = month.split('-').map(int.parse).toList();
    final next = DateTime(parts[0], parts[1] + delta);
    setState(() {
      month = '${next.year}-${next.month.toString().padLeft(2, '0')}';
      recordsFuture = widget.api.getAttendance(month: month);
    });
  }

  Future<void> download() async {
    final uri = await widget.api.attendancePdfUri(month);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (mounted) showCpSnack(context, launched ? 'Attendance sheet download started' : 'Unable to start download');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          const Expanded(child: Text('Monthly Attendance')),
          IconButton(onPressed: download, icon: const Icon(Icons.download, color: Cp.primary), tooltip: 'Export PDF'),
        ]),
        content: SizedBox(
          width: 720,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Center(child: Text(month, style: const TextStyle(color: Cp.primary, fontSize: 18, fontWeight: FontWeight.w900)))),
              IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_right)),
            ]),
            const SizedBox(height: 8),
            FutureBuilder<List<AttendanceRecord>>(
              future: recordsFuture,
              builder: (context, snapshot) {
                final records = snapshot.data ?? const <AttendanceRecord>[];
                if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator());
                if (records.isEmpty) return const EmptyStateCard(title: 'No attendance', message: 'Attendance records for this month will appear here.');
                final grouped = <String, List<AttendanceRecord>>{};
                for (final record in records) {
                  grouped.putIfAbsent(record.employeeId, () => []).add(record);
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      children: grouped.entries.map((entry) {
                        final employee = widget.employees.where((item) => item.id == entry.key).firstOrNull;
                        final name = employee?.name ?? entry.value.first.employeeName;
                        final present = entry.value.where((record) => record.status == 'present').length;
                        final absent = entry.value.where((record) => record.status == 'absent').length;
                        final partial = entry.value.where((record) => record.status == 'partial').length;
                        final hours = entry.value.fold<double>(0, (sum, record) => sum + record.hours);
                        final salary = entry.value.fold<int>(0, (sum, record) {
                          final ratio = record.status == 'present' ? 1.0 : record.status == 'partial' ? (record.hours / 8).clamp(0.0, 1.0) : 0.0;
                          return sum + (record.payPerDay * ratio).round();
                        });
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CpCard(
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)), Text('P $present • A $absent • Partial $partial • ${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} hrs', style: const TextStyle(color: Cp.onVariant))])),
                              Text(money(salary), style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
}

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, required this.profile, required this.onSave, required this.onClose});
  final BusinessProfile profile;
  final Future<void> Function(BusinessProfile profile) onSave;
  final VoidCallback onClose;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late final businessName = TextEditingController(text: widget.profile.businessName);
  late final serviceType = TextEditingController(text: widget.profile.serviceType);
  late final gstin = TextEditingController(text: widget.profile.gstin);
  late final pan = TextEditingController(text: widget.profile.pan);
  late final address = TextEditingController(text: widget.profile.address);
  late final phone = TextEditingController(text: widget.profile.phone);
  late final email = TextEditingController(text: widget.profile.email);
  late final bankName = TextEditingController(text: widget.profile.bankName);
  late final accountNumber = TextEditingController(text: widget.profile.accountNumber);
  late final terms = TextEditingController(text: widget.profile.terms);
  late String logoBase64 = widget.profile.logoBase64;
  late String signatureBase64 = widget.profile.signatureBase64;
  late String qrBase64 = widget.profile.qrBase64;
  late String documentTemplate = widget.profile.documentTemplate;
  bool saving = false;
  String? error;

  @override
  void didUpdateWidget(covariant BusinessProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile && !saving) {
      applyProfile(widget.profile);
    }
  }

  void applyProfile(BusinessProfile profile) {
    businessName.text = profile.businessName;
    serviceType.text = profile.serviceType;
    gstin.text = profile.gstin;
    pan.text = profile.pan;
    address.text = profile.address;
    phone.text = profile.phone;
    email.text = profile.email;
    bankName.text = profile.bankName;
    accountNumber.text = profile.accountNumber;
    terms.text = profile.terms;
    logoBase64 = profile.logoBase64;
    signatureBase64 = profile.signatureBase64;
    qrBase64 = profile.qrBase64;
    documentTemplate = profile.documentTemplate;
  }

  @override
  void dispose() {
    for (final controller in [businessName, serviceType, gstin, pan, address, phone, email, bankName, accountNumber, terms]) {
      controller.dispose();
    }
    super.dispose();
  }

  BusinessProfile currentProfile() => BusinessProfile(
        businessName: businessName.text.trim(),
        serviceType: serviceType.text.trim(),
        gstin: gstin.text.trim(),
        pan: pan.text.trim(),
        address: address.text.trim(),
        phone: phone.text.trim().isEmpty ? '' : normalizeMobileText(phone.text),
        email: email.text.trim(),
        bankName: bankName.text.trim(),
        accountNumber: accountNumber.text.trim(),
        terms: terms.text.trim(),
        logoBase64: logoBase64,
        signatureBase64: signatureBase64,
        qrBase64: qrBase64,
        documentTemplate: documentTemplate,
      );

  Future<void> save() async {
    final cleanPhone = normalizeMobileText(phone.text);
    if (businessName.text.trim().isEmpty) {
      setState(() => error = 'Business name is required.');
      return;
    }
    if (phone.text.trim().isNotEmpty && cleanPhone.length != 10) {
      setState(() => error = 'Phone number must be 10 digits.');
      return;
    }
    if (email.text.trim().isNotEmpty && !isValidEmail(email.text)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(currentProfile());
      if (!mounted) return;
      showCpSnack(context, 'Business profile saved');
      widget.onClose();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(topBar: TopBar(title: 'Business Profile', avatar: false, leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.arrow_back, color: Cp.primary)), actions: [TextButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save', style: const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)))]), children: [
        CpCard(child: Column(children: [BusinessLogoAvatar(profile: currentProfile(), radius: 44), const SizedBox(height: 12), const Text('Business Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const Text('Enter your business information', style: TextStyle(color: Cp.onVariant))])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: UploadBox(label: 'Logo', icon: Icons.storefront, value: logoBase64, filled: true, onChanged: (value) => setState(() => logoBase64 = value))),
          const SizedBox(width: 12),
          Expanded(child: UploadBox(label: 'Signature', icon: Icons.draw, value: signatureBase64, onChanged: (value) => setState(() => signatureBase64 = value))),
          const SizedBox(width: 12),
          Expanded(child: UploadBox(label: 'Payment QR', icon: Icons.qr_code_2, value: qrBase64, onChanged: (value) => setState(() => qrBase64 = value))),
        ]),
        const SizedBox(height: 16),
        if (error != null) ...[CpCard(color: Cp.errorContainer, child: Text(error!, style: const TextStyle(color: Cp.error, fontWeight: FontWeight.w800))), const SizedBox(height: 12)],
        const SectionTitle('Basic Info', Icons.business),
        EditableInlineField(label: 'Business Name', controller: businessName),
        EditableInlineField(label: 'Service Type', controller: serviceType),
        const SectionTitle('Tax & Legal', Icons.gavel),
        Row(children: [Expanded(child: EditableInlineField(label: 'GSTIN', controller: gstin)), const SizedBox(width: 12), Expanded(child: EditableInlineField(label: 'PAN', controller: pan))]),
        const SectionTitle('Business Address', Icons.location_on),
        EditableInlineField(label: 'Full Address', controller: address),
        const SectionTitle('Contact Information', Icons.contact_phone),
        EditableInlineField(label: 'Phone Number', controller: phone, keyboardType: TextInputType.phone, inputFormatters: mobileInputFormatters),
        EditableInlineField(label: 'Email Address', controller: email, keyboardType: TextInputType.emailAddress),
        const SectionTitle('Settlement Bank', Icons.account_balance),
        EditableInlineField(label: 'Bank Name', controller: bankName),
        EditableInlineField(label: 'Account Number', controller: accountNumber, keyboardType: TextInputType.number),
        const SectionTitle('Terms & Conditions', Icons.description),
        EditableInlineField(label: 'Standard Terms', controller: terms),
        const SectionTitle('Document Design', Icons.palette),
        CpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Invoice / Quotation / Menu Template', style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: documentTemplate,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: const [
                DropdownMenuItem(value: 'modern', child: Text('Modern Blue')),
                DropdownMenuItem(value: 'premium', child: Text('Premium Green & Gold')),
                DropdownMenuItem(value: 'minimal', child: Text('Minimal Black')),
              ],
              onChanged: (value) => setState(() => documentTemplate = value ?? 'modern'),
            ),
          ]),
        ),
      ]);
}

class UploadBox extends StatelessWidget {
  const UploadBox({super.key, required this.label, required this.icon, required this.value, required this.onChanged, this.filled = false});
  final String label;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final bool filled;

  Future<void> pickImage() async {
    final result = await fp.FilePicker.pickFiles(type: fp.FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    final ext = (file!.extension ?? '').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : ext == 'webp' ? 'image/webp' : 'image/png';
    onChanged('data:$mime;base64,${base64Encode(bytes)}');
  }

  @override
  Widget build(BuildContext context) {
    final bytes = bytesFromDataUrl(value);
    return AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
          decoration: BoxDecoration(color: filled ? Cp.primaryContainer : Cp.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: filled ? Cp.primaryContainer : Cp.outlineVariant, width: 1.4)),
          child: bytes == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: filled ? Colors.white : Cp.outline, size: 30), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: TextStyle(color: filled ? Colors.white : Cp.onVariant, fontSize: 11, fontWeight: FontWeight.w800)), Icon(value.isEmpty ? Icons.add_circle : Icons.edit, color: filled ? Colors.white : Cp.primary, size: 16)])
              : ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
          ),
        ),
      );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [Icon(icon, color: Cp.primary, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Cp.primary, fontSize: 16, fontWeight: FontWeight.w900))]),
      );
}
