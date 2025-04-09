const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const axios = require('axios');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(cors());
app.use(express.json());

const port = process.env.PORT || 3004;
const TMDB_API_KEY = process.env.TMDB_API_KEY;

// SQLite Setup
const db = new sqlite3.Database('events.db');
db.serialize(() => {
  db.run('CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, date TEXT)');
  db.run('CREATE TABLE IF NOT EXISTS bookings (id INTEGER PRIMARY KEY AUTOINCREMENT, eventId INTEGER, userName TEXT, FOREIGN KEY(eventId) REFERENCES events(id))');
  db.run("INSERT OR IGNORE INTO events (name, date) VALUES ('Concert', '2025-04-15')");
  db.run("INSERT OR IGNORE INTO events (name, date) VALUES ('Workshop', '2025-04-20')");
});

// Movie Routes
app.get('/api/movies', async (req, res) => {
  try {
    const response = await axios.get(
      `https://api.themoviedb.org/3/movie/popular?api_key=${TMDB_API_KEY}&language=en-US&page=1`
    );
    res.json(response.data.results);
  } catch (error) {
    res.status(500).send(error.message);
  }
});

app.get('/api/recommendations', async (req, res) => {
  const { genre } = req.query;
  try {
    const response = await axios.get(
      `https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&with_genres=${genre}&language=en-US`
    );
    res.json(response.data.results.slice(0, 5));
  } catch (error) {
    res.status(500).send(error.message);
  }
});

// Event Routes
app.get('/api/events', (req, res) => {
  db.all('SELECT * FROM events', [], (err, rows) => {
    if (err) return res.status(500).send(err.message);
    res.json(rows);
  });
});

app.post('/api/bookings', (req, res) => {
  const { eventId, userName } = req.body;
  db.run('INSERT INTO bookings (eventId, userName) VALUES (?, ?)', [eventId, userName], function(err) {
    if (err) return res.status(400).send(err.message);
    res.status(201).send({ id: this.lastID });
  });
});

// WebSocket for Stock Ticker
wss.on('connection', (ws) => {
  console.log('Client connected');
  const interval = setInterval(() => {
    const stockUpdate = {
      symbol: 'AAPL',
      price: (Math.random() * 10 + 140).toFixed(2),
      timestamp: new Date().toISOString(),
    };
    ws.send(JSON.stringify(stockUpdate));
  }, 2000);

  ws.on('close', () => {
    clearInterval(interval);
    console.log('Client disconnected');
  });
});

server.listen(port, () => {
  console.log(`Integrated App running on port ${port}`);
});