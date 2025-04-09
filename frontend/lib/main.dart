import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/html.dart' show HtmlWebSocketChannel;
import 'package:fl_chart/fl_chart.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:io' show Platform;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: IntegratedScreen());
}

class IntegratedScreen extends StatefulWidget {
  @override
  _IntegratedScreenState createState() => _IntegratedScreenState();
}

class _IntegratedScreenState extends State<IntegratedScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [MovieTab(), EventTab()];
  final TextEditingController _userNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Integrated Scheduler, Stock & Event App')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Movies'),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.show_chart),
          //   label: 'Stocks',
          // ),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
        ],
      ),
    );
  }
}

class MovieTab extends StatefulWidget {
  @override
  _MovieTabState createState() => _MovieTabState();
}

class _MovieTabState extends State<MovieTab> {
  List<dynamic> movies = [];

  Future<void> fetchMovies() async {
    final response = await http.get(
      Uri.parse('http://localhost:3004/api/movies'),
    );
    if (response.statusCode == 200) {
      setState(() {
        movies = jsonDecode(response.body);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      items:
          movies
              .map(
                (movie) => Container(
                  margin: EdgeInsets.all(5.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(Icons.error),
                    ),
                  ),
                ),
              )
              .toList(),
      options: CarouselOptions(
        height: 400,
        enlargeCenterPage: true,
        autoPlay: true,
      ),
    );
  }
}

class StockTab extends StatefulWidget {
  @override
  _StockTabState createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  dynamic channel; // Use dynamic to handle both IO and Html WebSocket
  List<FlSpot> dataPoints = [];
  double maxY = 150;

  @override
  void initState() {
    super.initState();
    // Choose WebSocket channel based on platform
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isFuchsia ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isWindows) {
      channel = IOWebSocketChannel.connect('ws://localhost:3004');
    } else {
      // Web platform
      channel = HtmlWebSocketChannel.connect('ws://localhost:3004');
    }
    channel.stream.listen((message) {
      final data = jsonDecode(message);
      setState(() {
        dataPoints.add(
          FlSpot(dataPoints.length.toDouble(), double.parse(data['price'])),
        );
        if (dataPoints.length > 10) dataPoints.removeAt(0);
        maxY = dataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10;
      });
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          lineBarsData: [LineChartBarData(spots: dataPoints)],
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          maxY: maxY,
        ),
      ),
    );
  }
}

class EventTab extends StatefulWidget {
  @override
  _EventTabState createState() => _EventTabState();
}

class _EventTabState extends State<EventTab> {
  List<dynamic> events = [];
  final TextEditingController _userNameController = TextEditingController();
  Future<void> fetchEvents() async {
    final response = await http.get(
      Uri.parse('http://localhost:3004/api/events'),
    );
    if (response.statusCode == 200) {
      setState(() {
        events = jsonDecode(response.body);
      });
    }
  }

  Future<void> bookEvent(int eventId) async {
    final response = await http.post(
      Uri.parse('http://localhost:3004/api/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'eventId': eventId,
        'userName': _userNameController.text,
      }),
    );
    if (response.statusCode == 201) {
      print('Booking successful');
    } else {
      print('Error: ${response.body}');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder:
                (context, index) => ListTile(
                  title: Text(events[index]['name']),
                  subtitle: Text(events[index]['date']),
                  trailing: ElevatedButton(
                    onPressed: () => bookEvent(events[index]['id']),
                    child: Text('Book'),
                  ),
                ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: TextField(
            controller: _userNameController,
            decoration: InputDecoration(labelText: 'Your Name'),
          ),
        ),
      ],
    );
  }
}
