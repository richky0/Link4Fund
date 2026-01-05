import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const Click4FunApp());
}

// Model untuk Link
class Link {
  final String id;
  final String title;
  final String url;
  final String icon;
  final int colorValue;

  Link({
    required this.id,
    required this.title,
    required this.url,
    required this.icon,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'icon': icon,
    'colorValue': colorValue,
  };

  factory Link.fromJson(Map<String, dynamic> json) => Link(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    icon: json['icon'],
    colorValue: json['colorValue'],
  );
}

// Helper untuk membuat warna
int getColorValue(int r, int g, int b) {
  return (0xFF << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
}

// Service untuk menyimpan link
class LinkService {
  static const String _key = 'click4fun_links';

  Future<List<Link>> getLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return _getDefaultLinks();

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Link.fromJson(json)).toList();
    } catch (e) {
      return _getDefaultLinks();
    }
  }

  Future<void> saveLinks(List<Link> links) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = links.map((link) => link.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  List<Link> _getDefaultLinks() {
    return [
      Link(
        id: '1',
        title: 'Google',
        url: 'https://google.com',
        icon: '🌐',
        colorValue: getColorValue(66, 133, 244),
      ),
    ];
  }
}

// Main App
class Click4FunApp extends StatelessWidget {
  const Click4FunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link4Fun',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LinkService _linkService = LinkService();
  late Future<List<Link>> _linksFuture;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _linksFuture = _linkService.getLinks();
  }

  Future<void> _refreshLinks() async {
    setState(() {
      _linksFuture = _linkService.getLinks();
    });
  }

  Future<void> _addLink() async {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();

    if (title.isEmpty || url.isEmpty) {
      _showError('Please fill in both title and URL');
      return;
    }

    final links = await _linkService.getLinks();
    final newLink = Link(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      url: url.startsWith('http') ? url : 'https://$url',
      icon: '🔗',
      colorValue: getColorValue(33, 150, 243),
    );

    links.add(newLink);
    await _linkService.saveLinks(links);

    _titleController.clear();
    _urlController.clear();

    if (!mounted) return;

    _refreshLinks();
    _showSuccess('Link added successfully!');
  }

  Future<void> _deleteLink(Link link) async {
    final links = await _linkService.getLinks();
    links.removeWhere((l) => l.id == link.id);
    await _linkService.saveLinks(links);

    if (!mounted) return;

    _refreshLinks();
    _showSuccess('Link deleted', isError: true);
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showCopySuccess(text);
    }
  }

  void _showCopySuccess(String copiedText) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Link Copied!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    copiedText,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }

      final uri = Uri.parse(finalUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showError('No app found to open this URL');
      }
    } catch (e) {
      _showError('Failed to open: $url');
    }
  }

  void _showSuccess(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // FUNGSI QR CODE YANG DIPERBAIKI
  void _showQRCodeDialog(Link link) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code, color: link.color, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'QR Code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: link.color,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: link.color.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: link.url,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: link.color,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Link Info
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: link.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: link.color,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        link.url,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(link.url),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy URL'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl(link.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open Link'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: link.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fungsi save QR Code (sederhana)
  Future<void> _saveQRCodeSimple(Link link) async {
    try {
      // Untuk save QR Code, kita perlu RenderRepaintBoundary
      // Ini implementasi sederhana dulu
      final GlobalKey qrKey = GlobalKey();

      // Tampilkan dialog dengan QR
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Save QR for ${link.title}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: link.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: RepaintBoundary(
                    key: qrKey,
                    child: QrImageView(
                      data: link.url,
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Screenshot this QR Code to save it',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _copyToClipboard(link.url);
                  _showSuccess('URL copied! You can paste it to generate QR elsewhere.');
                },
                child: const Text('Copy URL Instead'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }
  }

  void _showAddLinkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter link title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'example.com',
                border: OutlineInputBorder(),
                prefixText: 'https://',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addLink();
            },
            child: const Text('Add Link'),
          ),
        ],
      ),
    );
  }

  void _showLinkOptions(Link link) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: link.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code, color: link.color),
            ),
            title: Text(
              'Generate QR Code',
              style: TextStyle(fontWeight: FontWeight.bold, color: link.color),
            ),
            subtitle: const Text('Create QR code for this link'),
            onTap: () {
              Navigator.pop(context);
              _showQRCodeDialog(link);
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.open_in_new, color: Colors.blue),
            ),
            title: const Text(
              'Open Link',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              _launchUrl(link.url);
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.copy, color: Colors.green),
            ),
            title: const Text(
              'Copy URL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              _copyToClipboard(link.url);
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit, color: Colors.orange),
            ),
            title: const Text(
              'Edit Link',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              _editLink(link);
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            title: const Text(
              'Delete Link',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteLink(link);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _editLink(Link link) async {
    _titleController.text = link.title;
    _urlController.text = link.url.replaceFirst('https://', '').replaceFirst('http://', '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
                prefixText: 'https://',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final links = await _linkService.getLinks();
              final index = links.indexWhere((l) => l.id == link.id);

              if (index != -1) {
                final title = _titleController.text.trim();
                final url = _urlController.text.trim();

                if (title.isEmpty || url.isEmpty) {
                  _showError('Please fill in both title and URL');
                  return;
                }

                links[index] = Link(
                  id: link.id,
                  title: title,
                  url: url.startsWith('http') ? url : 'https://$url',
                  icon: link.icon,
                  colorValue: link.colorValue,
                );

                await _linkService.saveLinks(links);
                _refreshLinks();
                _showSuccess('Link updated successfully!');
              }

              _titleController.clear();
              _urlController.clear();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link4Fun'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLinks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Link>>(
        future: _linksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading links',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshLinks,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_link,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to Link4Fun',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Add your favorite links and access them with one tap',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showAddLinkDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Link'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          final links = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Your Links (${links.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showAddLinkDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    final link = links[index];
                    return GestureDetector(
                      onLongPress: () => _showLinkOptions(link),
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: link.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                link.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          title: Text(
                            link.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            link.url,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.qr_code,
                                  size: 22,
                                  color: link.color,
                                ),
                                onPressed: () => _showQRCodeDialog(link),
                                tooltip: 'Generate QR Code',
                              ),
                              const SizedBox(width: 5),
                              IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 24,
                                ),
                                onPressed: () => _showLinkOptions(link),
                              ),
                            ],
                          ),
                          onTap: () => _launchUrl(link.url),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLinkDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Link'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}