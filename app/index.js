const express = require('express');
const app = express();
const PORT = 8080;

app.get('/', (req, res) => {
  res.send("Hello! This is Vidumini's Cloud Infrastructure Assignment.");
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});