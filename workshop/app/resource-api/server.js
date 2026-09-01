const express = require('express');
const app = express();
app.use(express.json());

// Identifies which "tenant" (NGO) this instance represents — set per-deployment
// via env var so one image serves every namespace in the Cooperation hour.
const NGO_ID = process.env.NGO_ID || 'demo';
const PORT = process.env.PORT || 8080;

// In-memory store keeps the app dependency-free (no DB to install) —
// fine for a workshop, not for production.
let resources = [
  { id: 1, name: 'Solar panel (2kW)', owner: NGO_ID },
  { id: 2, name: 'Water purification kit', owner: NGO_ID }
];

// Used by Kubernetes liveness/readiness probes in the Resilience hour,
// and as a quick manual check right after deploy.
app.get('/health', (req, res) => {
  res.json({ status: 'ok', ngo: NGO_ID, uptime: process.uptime() });
});

app.get('/resources', (req, res) => {
  res.json(resources);
});

app.post('/resources', (req, res) => {
  const { name } = req.body || {};
  if (!name) return res.status(400).json({ error: 'name is required' });
  const resource = { id: resources.length + 1, name, owner: NGO_ID };
  resources.push(resource);
  res.status(201).json(resource);
});

app.listen(PORT, () => {
  console.log(`resource-api (ngo=${NGO_ID}) listening on port ${PORT}`);
});
