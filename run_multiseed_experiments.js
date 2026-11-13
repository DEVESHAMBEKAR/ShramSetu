/**
 * ShramSetu FairMatch Engine - Unified Multi-Seed Experimental Benchmark
 * 
 * Evaluates 7 baseline algorithms, multi-factor ablation, parametric sensitivity sweep,
 * and 4 geographic clustering scenarios across 5 independent random seeds (5,000 total simulated transactions).
 * 
 * Strict Eq. 4 Job Lifecycle Semantics:
 * - When booked: worker.activeBookings += 1
 * - When job completes: worker.activeBookings -= 1, worker.recent7dBookings += 1
 * - When 7-day window expires: worker.recent7dBookings -= 1
 */

const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

// Mulberry32 Deterministic PRNG
function createPRNG(seed) {
  let s = seed >>> 0;
  return function() {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Spherical Haversine distance in kilometers (Earth R = 6371.0 km)
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371.0;
  const dLat = (lat2 - lat1) * Math.PI / 180.0;
  const dLon = (lon2 - lon1) * Math.PI / 180.0;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180.0) * Math.cos(lat2 * Math.PI / 180.0) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Jain's Fairness Index: J(x) = (sum x_i)^2 / (n * sum x_i^2)
function calculateJainsIndex(values) {
  const n = values.length;
  if (n === 0) return 1.0;
  let sum = 0.0, sumSq = 0.0;
  for (let i = 0; i < n; i++) {
    sum += values[i];
    sumSq += values[i] * values[i];
  }
  return sumSq === 0 ? 1.0 : (sum * sum) / (n * sumSq);
}

// Gini Coefficient: G in [0, 1]
function calculateGini(values) {
  const n = values.length;
  if (n === 0) return 0.0;
  const sorted = [...values].sort((a, b) => a - b);
  const total = sorted.reduce((acc, v) => acc + v, 0);
  if (total === 0) return 0.0;
  let cumulativeSum = 0;
  for (let i = 0; i < n; i++) cumulativeSum += (2 * (i + 1) - n - 1) * sorted[i];
  return cumulativeSum / (n * total);
}

// Top-10% Exposure Share: percentage of total exposure consumed by top 10%
function calculateTop10Share(values) {
  const total = values.reduce((acc, v) => acc + v, 0);
  if (total === 0) return 0.0;
  const sorted = [...values].sort((a, b) => b - a);
  const top10Count = Math.max(1, Math.floor(values.length * 0.10));
  const top10Sum = sorted.slice(0, top10Count).reduce((acc, v) => acc + v, 0);
  return (top10Sum / total) * 100.0;
}

const TRADES = ['plumber', 'electrician', 'carpenter', 'cleaner', 'painter'];
const PUNE_CENTER = { lat: 18.5204, lon: 73.8567 };
const NUM_WORKERS = 250;
const NUM_REQUESTS = 1000;
const SEEDS = [42, 101, 777, 2024, 9999];

// Generate Worker Pool
function generateWorkerPool(rand, workerDist = 'uniform') {
  const workers = [];
  for (let i = 0; i < NUM_WORKERS; i++) {
    const trade = TRADES[i % TRADES.length];
    let wLat, wLon;

    if (workerDist === 'uniform') {
      const r = Math.sqrt(rand()) * 0.09; // ~10 km radius
      const theta = rand() * 2 * Math.PI;
      wLat = PUNE_CENTER.lat + r * Math.cos(theta);
      wLon = PUNE_CENTER.lon + r * Math.sin(theta);
    } else {
      // Clustered: two major artisan hubs in Pune (East: Hadapsar, West: Kothrud)
      const isEast = rand() < 0.50;
      const hubLat = isEast ? PUNE_CENTER.lat + 0.025 : PUNE_CENTER.lat - 0.025;
      const hubLon = isEast ? PUNE_CENTER.lon + 0.035 : PUNE_CENTER.lon - 0.035;
      const r = Math.sqrt(rand()) * 0.022; // ~2.5 km cluster radius
      const theta = rand() * 2 * Math.PI;
      wLat = hubLat + r * Math.cos(theta);
      wLon = hubLon + r * Math.sin(theta);
    }

    const isCold = rand() < 0.15;
    let rating = 0.0, reviewCount = 0;
    if (!isCold) {
      const u1 = rand(), u2 = rand();
      const z = Math.sqrt(-2.0 * Math.log(u1 || 0.001)) * Math.cos(2.0 * Math.PI * u2);
      rating = Math.max(2.5, Math.min(5.0, 4.35 + z * 0.45));
      rating = Math.round(rating * 10) / 10;
      reviewCount = Math.floor(rand() * 80) + 3;
    }

    const expYears = Math.min(15, Math.max(1, Math.floor(rand() * 12) + 1));
    const isAvail = rand() < 0.90;
    const hasSkill = rand() < 0.95;
    const isAct = rand() < 0.95 ? 'ACTIVE' : 'SUSPENDED';

    workers.push({
      id: `w_${String(i).padStart(3, '0')}`,
      category: trade,
      lat: wLat,
      lon: wLon,
      rating,
      reviewCount,
      experienceYears: expYears,
      isAvailable: isAvail,
      hasVerifiedSkill: hasSkill,
      workerStatus: isAct,
      hasCoordinates: true,
      activeBookings: 0,
      recent7dBookings: 0,
      completedJobs: reviewCount * 2,
    });
  }
  return workers;
}

// Generate Request Stream
function generateRequestStream(rand, demandDist = 'uniform') {
  const requests = [];
  for (let t = 0; t < NUM_REQUESTS; t++) {
    const trade = TRADES[Math.floor(rand() * TRADES.length)];
    let cLat, cLon;

    if (demandDist === 'uniform') {
      const r = Math.sqrt(rand()) * 0.09;
      const theta = rand() * 2 * Math.PI;
      cLat = PUNE_CENTER.lat + r * Math.cos(theta);
      cLon = PUNE_CENTER.lon + r * Math.sin(theta);
    } else {
      // Clustered demand: 75% customer requests concentrated in 2.0 km commercial core
      if (rand() < 0.75) {
        const r = Math.sqrt(rand()) * 0.018; // ~2.0 km commercial core
        const theta = rand() * 2 * Math.PI;
        cLat = PUNE_CENTER.lat + r * Math.cos(theta);
        cLon = PUNE_CENTER.lon + r * Math.sin(theta);
      } else {
        const r = Math.sqrt(rand()) * 0.09;
        const theta = rand() * 2 * Math.PI;
        cLat = PUNE_CENTER.lat + r * Math.cos(theta);
        cLon = PUNE_CENTER.lon + r * Math.sin(theta);
      }
    }
    requests.push({ category: trade, lat: cLat, lon: cLon });
  }
  return requests;
}

// Simulate Run for one algorithm and one seed
function simulateRun(algorithm, weights, seed, workerDist = 'uniform', demandDist = 'uniform') {
  const workerRand = createPRNG(seed);
  const workers = generateWorkerPool(workerRand, workerDist);

  const reqRand = createPRNG(seed + 1000);
  const requests = generateRequestStream(reqRand, demandDist);

  const choicePRNG = createPRNG(seed + 2000);

  const exposureMap = {};
  const bookingMap = {};
  workers.forEach(w => {
    exposureMap[w.id] = 0.0;
    bookingMap[w.id] = 0;
  });

  let totalTop1Distance = 0.0;
  let totalTop1Rating = 0.0;
  let totalTop1Exp = 0.0;
  let totalColdStartInTop5 = 0;
  let validRequests = 0;
  let roundRobinPointer = 0;

  const latencies = [];

  for (let t = 0; t < requests.length; t++) {
    const req = requests[t];
    const eligible = workers.filter(w => 
      w.workerStatus === 'ACTIVE' &&
      w.isAvailable &&
      w.hasVerifiedSkill &&
      w.category === req.category
    );

    if (eligible.length === 0) continue;
    validRequests++;

    const tStart = performance.now();
    let ranked = [];

    if (algorithm === 'round_robin') {
      // Round-robin: select cyclically among verified candidates within 15 km
      const nearby = eligible.map(w => ({
        candidate: w,
        distanceKm: haversineDistance(req.lat, req.lon, w.lat, w.lon)
      })).filter(item => item.distanceKm <= 15.0);

      const pool = nearby.length > 0 ? nearby : eligible.map(w => ({ candidate: w, distanceKm: haversineDistance(req.lat, req.lon, w.lat, w.lon) }));
      const nPool = pool.length;
      ranked = [];
      for (let i = 0; i < Math.min(5, nPool); i++) {
        const idx = (roundRobinPointer + i) % nPool;
        ranked.push({ candidate: pool[idx].candidate, totalScore: 1.0 - i * 0.1, distanceKm: pool[idx].distanceKm });
      }
      roundRobinPointer = (roundRobinPointer + 1) % 10000;
    } else {
      const scored = eligible.map(w => {
        const d = haversineDistance(req.lat, req.lon, w.lat, w.lon);
        const sDist = Math.max(0.0, Math.min(1.0, 1.0 - (d / 15.0)));
        const sRating = (w.reviewCount > 0) ? Math.max(0.0, Math.min(1.0, (w.rating - 1.0) / 4.0)) : 0.5;
        const sExp = Math.min(1.0, w.experienceYears / 10.0);
        const rawWorkload = (w.activeBookings * 2.0) + w.recent7dBookings;
        const sFair = Math.max(0.0, Math.min(1.0, 1.0 - (Math.min(10.0, rawWorkload) / 10.0)));

        let totalScore = 0.0;
        if (algorithm === 'nearest') {
          totalScore = sDist;
        } else if (algorithm === 'highest_rated') {
          totalScore = sRating;
        } else if (algorithm === 'rating_distance') {
          totalScore = 0.5 * sDist + 0.5 * sRating;
        } else if (algorithm === 'nearest_least_loaded') {
          totalScore = 0.70 * sDist + 0.30 * sFair;
        } else {
          totalScore = (weights.skill * 1.0) +
                       (weights.distance * sDist) +
                       (weights.availability * 1.0) +
                       (weights.rating * sRating) +
                       (weights.experience * sExp) +
                       (weights.fairness * sFair);
        }

        return {
          candidate: w,
          totalScore,
          skillScore: 1.0,
          distanceKm: d,
        };
      });

      // Deterministic v1 cascade: totalScore DESC, skillScore DESC, distanceKm ASC, worker_id ASC
      scored.sort((a, b) => {
        if (b.totalScore !== a.totalScore) return b.totalScore - a.totalScore;
        if (b.skillScore !== a.skillScore) return b.skillScore - a.skillScore;
        if (a.distanceKm !== b.distanceKm) return a.distanceKm - b.distanceKm;
        return a.candidate.id.localeCompare(b.candidate.id);
      });

      ranked = scored;
    }

    const tEnd = performance.now();
    latencies.push(tEnd - tStart);

    const top1 = ranked[0].candidate;
    totalTop1Distance += ranked[0].distanceKm;
    totalTop1Rating += (top1.reviewCount > 0 ? top1.rating : 3.0);
    totalTop1Exp += top1.experienceYears;

    const k = Math.min(5, ranked.length);
    for (let r = 0; r < k; r++) {
      const item = ranked[r].candidate;
      const discount = 1.0 / Math.log2(r + 2);
      exposureMap[item.id] += discount;
      if (item.reviewCount === 0) totalColdStartInTop5++;
    }

    // Downstream customer choice model (60% rank 1, 25% rank 2, 15% rank 3)
    const pickRand = choicePRNG();
    let pickedRank = (pickRand < 0.60 || ranked.length === 1) ? 0 : ((pickRand < 0.85 || ranked.length === 2) ? 1 : Math.min(2, ranked.length - 1));
    const bookedId = ranked[pickedRank].candidate.id;
    bookingMap[bookedId] = (bookingMap[bookedId] || 0) + 1;

    // Strict Eq. 4 Implementation:
    // When booked: ONLY activeBookings increments!
    const bookedWorker = workers.find(w => w.id === bookedId);
    if (bookedWorker) {
      bookedWorker.activeBookings += 1;
    }

    // Workload completion decay:
    // When an active job completes: activeBookings decrements, recent7dBookings increments!
    if (t % 5 === 0) {
      for (const w of workers) {
        if (w.activeBookings > 0 && choicePRNG() < 0.40) {
          w.activeBookings--;
          w.recent7dBookings++;
        }
      }
    }

    // Trailing 7-day completed bookings decay out of the window
    if (t % 40 === 0) {
      for (const w of workers) {
        if (w.recent7dBookings > 0 && choicePRNG() < 0.25) {
          w.recent7dBookings--;
        }
      }
    }
  }

  const activeWorkers = workers.filter(w => w.workerStatus === 'ACTIVE' && w.hasVerifiedSkill);
  const exposures = activeWorkers.map(w => exposureMap[w.id]);
  const bookings = activeWorkers.map(w => bookingMap[w.id]);
  const workloads = activeWorkers.map(w => (w.activeBookings * 2.0) + w.recent7dBookings);

  const zeroExp = exposures.filter(e => e === 0.0).length;
  const zeroBookings = bookings.filter(b => b === 0).length;

  latencies.sort((a, b) => a - b);
  const meanLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
  const medianLatency = latencies[Math.floor(latencies.length * 0.5)];
  const p95Latency = latencies[Math.floor(latencies.length * 0.95)];

  return {
    exposureJain: calculateJainsIndex(exposures),
    exposureGini: calculateGini(exposures),
    top10Share: calculateTop10Share(exposures),
    exposureStarvation: (zeroExp / activeWorkers.length) * 100,
    bookingJain: calculateJainsIndex(bookings),
    bookingGini: calculateGini(bookings),
    bookingStarvation: (zeroBookings / activeWorkers.length) * 100,
    workloadJain: calculateJainsIndex(workloads),
    workloadGini: calculateGini(workloads),
    top1DistanceKm: totalTop1Distance / validRequests,
    top1Rating: totalTop1Rating / validRequests,
    top1ExpYears: totalTop1Exp / validRequests,
    coldStartTop5Pct: (totalColdStartInTop5 / (validRequests * 5)) * 100,
    meanLatencyMs: meanLatency,
    medianLatencyMs: medianLatency,
    p95LatencyMs: p95Latency,
  };
}

// Helper to compute aggregate statistics over 5 seeds
function aggregateSeedRuns(runs) {
  const mean = k => runs.reduce((a, b) => a + b[k], 0) / runs.length;
  const std = (k, m) => Math.sqrt(runs.reduce((a, b) => a + Math.pow(b[k] - m, 2), 0) / runs.length);

  const agg = {};
  for (const k of Object.keys(runs[0])) {
    const m = mean(k);
    const s = std(k, m);
    agg[k] = {
      mean: Number(m.toFixed(4)),
      std: Number(s.toFixed(4)),
      formatted: `${m.toFixed(3)} ± ${s.toFixed(3)}`
    };
  }
  return agg;
}

// Main Benchmark Execution
console.log('Starting ShramSetu FairMatch Multi-Seed Benchmark...');
const benchStart = performance.now();

// 1. Core Baselines & Main Benchmark
const BASELINES = {
  'nearest': { name: 'Nearest-First (Proximity Only)', weights: null },
  'highest_rated': { name: 'Highest-Rated (Reputation Only)', weights: null },
  'rating_distance': { name: 'Rating + Distance', weights: null },
  'nearest_least_loaded': { name: 'Nearest + Least-Loaded (Workload-Aware Proximity)', weights: null },
  'round_robin': { name: 'Round-Robin (Cyclic Task Allocation)', weights: null },
  'ablation_no_fairness': { name: 'FairMatch Ablation (w_fair=0)', weights: { skill: 0.35, distance: 0.25, availability: 0.15, rating: 0.125, experience: 0.125, fairness: 0.0 } },
  'fairmatch_v1': { name: 'FairMatch v1 (Default 10% Fairness)', weights: { skill: 0.35, distance: 0.20, availability: 0.15, rating: 0.10, experience: 0.10, fairness: 0.10 } },
};

// 2. Multi-Factor Ablation Suite
const ABLATION_SUITE = {
  'full_fairmatch': { name: 'Full FairMatch v1', weights: { skill: 0.35, distance: 0.20, availability: 0.15, rating: 0.10, experience: 0.10, fairness: 0.10 } },
  'ablation_no_fairness': { name: 'Ablation: No Fairness (w_fair=0)', weights: { skill: 0.35, distance: 0.25, availability: 0.15, rating: 0.125, experience: 0.125, fairness: 0.0 } },
  'ablation_no_distance': { name: 'Ablation: No Distance (w_dist=0)', weights: { skill: 0.35, distance: 0.0, availability: 0.15, rating: 0.1667, experience: 0.1667, fairness: 0.1666 } },
  'ablation_no_rating': { name: 'Ablation: No Rating (w_rate=0)', weights: { skill: 0.35, distance: 0.25, availability: 0.15, rating: 0.0, experience: 0.125, fairness: 0.125 } },
  'ablation_no_experience': { name: 'Ablation: No Experience (w_exp=0)', weights: { skill: 0.35, distance: 0.25, availability: 0.15, rating: 0.125, experience: 0.0, fairness: 0.125 } },
};

// 3. Parametric Sensitivity Suite
const SENSITIVITY_SUITE = {
  'sensitivity_fair_00': { name: 'Sensitivity: w_fair = 0.00', weights: { skill: 0.35, distance: 0.25, availability: 0.15, rating: 0.125, experience: 0.125, fairness: 0.00 } },
  'sensitivity_fair_05': { name: 'Sensitivity: w_fair = 0.05', weights: { skill: 0.35, distance: 0.225, availability: 0.15, rating: 0.1125, experience: 0.1125, fairness: 0.05 } },
  'sensitivity_fair_10': { name: 'Sensitivity: w_fair = 0.10', weights: { skill: 0.35, distance: 0.20, availability: 0.15, rating: 0.10, experience: 0.10, fairness: 0.10 } },
  'sensitivity_fair_15': { name: 'Sensitivity: w_fair = 0.15', weights: { skill: 0.35, distance: 0.175, availability: 0.15, rating: 0.0875, experience: 0.0875, fairness: 0.15 } },
  'sensitivity_fair_20': { name: 'Sensitivity: w_fair = 0.20', weights: { skill: 0.35, distance: 0.15, availability: 0.15, rating: 0.075, experience: 0.075, fairness: 0.20 } },
};

// 4. Geographic Clustering Suite (Scenarios A–D)
const CLUSTERING_SCENARIOS = [
  { key: 'scenario_a', name: 'Scenario A: Uniform Workers, Uniform Demand', wDist: 'uniform', dDist: 'uniform' },
  { key: 'scenario_b', name: 'Scenario B: Clustered Workers, Uniform Demand', wDist: 'clustered', dDist: 'uniform' },
  { key: 'scenario_c', name: 'Scenario C: Uniform Workers, Clustered Demand', wDist: 'uniform', dDist: 'clustered' },
  { key: 'scenario_d', name: 'Scenario D: Clustered Workers, Clustered Demand', wDist: 'clustered', dDist: 'clustered' },
];

const rawSeedOutputs = {};
SEEDS.forEach(s => rawSeedOutputs[s] = {});

// Run Baselines
const aggregateBaselines = {};
for (const [key, def] of Object.entries(BASELINES)) {
  const runs = SEEDS.map(s => {
    const r = simulateRun(key, def.weights, s, 'uniform', 'uniform');
    rawSeedOutputs[s][key] = r;
    return r;
  });
  aggregateBaselines[key] = { name: def.name, ...aggregateSeedRuns(runs) };
}

// Run Ablation
const aggregateAblation = {};
for (const [key, def] of Object.entries(ABLATION_SUITE)) {
  const runs = SEEDS.map(s => simulateRun(key === 'full_fairmatch' ? 'fairmatch_v1' : key, def.weights, s, 'uniform', 'uniform'));
  aggregateAblation[key] = { name: def.name, ...aggregateSeedRuns(runs) };
}

// Run Sensitivity
const aggregateSensitivity = {};
for (const [key, def] of Object.entries(SENSITIVITY_SUITE)) {
  const runs = SEEDS.map(s => simulateRun('fairmatch_v1', def.weights, s, 'uniform', 'uniform'));
  aggregateSensitivity[key] = { name: def.name, ...aggregateSeedRuns(runs) };
}

// Run Spatial Clustering
const aggregateClustering = {};
for (const sc of CLUSTERING_SCENARIOS) {
  aggregateClustering[sc.key] = { name: sc.name, algorithms: {} };
  for (const algoKey of ['nearest', 'nearest_least_loaded', 'fairmatch_v1', 'ablation_no_fairness']) {
    const w = BASELINES[algoKey].weights;
    const runs = SEEDS.map(s => simulateRun(algoKey, w, s, sc.wDist, sc.dDist));
    aggregateClustering[sc.key].algorithms[algoKey] = aggregateSeedRuns(runs);
  }
}

const benchDuration = ((performance.now() - benchStart) / 1000).toFixed(2);
console.log(`Benchmark completed in ${benchDuration} seconds.\n`);

// Save Results to disk
const outDir = 'C:/ShramSetu/benchmark_results';
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

for (const s of SEEDS) {
  fs.writeFileSync(path.join(outDir, `raw_seed_${s}.json`), JSON.stringify(rawSeedOutputs[s], null, 2));
}

const fullAggregatePayload = {
  metadata: {
    commit: 'f7bce061338e94ef4f350f4deb90acc9dc17b2b3',
    repository: 'https://github.com/ShramSetu/ShramSetu',
    seeds: SEEDS,
    numWorkers: NUM_WORKERS,
    numRequests: NUM_REQUESTS,
    totalSimulatedTransactions: SEEDS.length * NUM_REQUESTS,
    executionDurationSeconds: Number(benchDuration)
  },
  baselines: aggregateBaselines,
  ablation: aggregateAblation,
  sensitivity: aggregateSensitivity,
  clustering: aggregateClustering
};

fs.writeFileSync(path.join(outDir, 'unified_aggregate_results.json'), JSON.stringify(fullAggregatePayload, null, 2));

// Print Tables for Terminal Log
console.log('=== TABLE II-A & II-B: BASELINE COMPARISON SUMMARY (MEAN ± STD DEV) ===');
console.log('Algorithm'.padEnd(25) + ' | Exp Jain        | Book Jain       | Work Jain       | Exp Starv (%)   | Book Starv (%)  | Top-1 Dist    | Top-1 Rate');
for (const [k, d] of Object.entries(aggregateBaselines)) {
  console.log(
    k.padEnd(25) + ' | ' +
    d.exposureJain.formatted.padEnd(15) + ' | ' +
    d.bookingJain.formatted.padEnd(15) + ' | ' +
    d.workloadJain.formatted.padEnd(15) + ' | ' +
    d.exposureStarvation.formatted.padEnd(15) + ' | ' +
    d.bookingStarvation.formatted.padEnd(15) + ' | ' +
    d.top1DistanceKm.formatted.padEnd(13) + ' | ' +
    d.top1Rating.formatted
  );
}

console.log('\n=== TABLE III: MULTI-FACTOR ABLATION STUDY ===');
console.log('Configuration'.padEnd(25) + ' | Exp Jain        | Exp Gini        | Exp Starv (%)   | Top-1 Dist    | Top-1 Rating');
for (const [k, d] of Object.entries(aggregateAblation)) {
  console.log(
    k.padEnd(25) + ' | ' +
    d.exposureJain.formatted.padEnd(15) + ' | ' +
    d.exposureGini.formatted.padEnd(15) + ' | ' +
    d.exposureStarvation.formatted.padEnd(15) + ' | ' +
    d.top1DistanceKm.formatted.padEnd(13) + ' | ' +
    d.top1Rating.formatted
  );
}

console.log('\n=== TABLE IV: SENSITIVITY SWEEP OVER FAIRNESS WEIGHT ===');
console.log('Weight'.padEnd(25) + ' | Exp Jain | Book Jain | Work Jain | Top-10%  | Exp Starv | Book Starv | Top-1 Dist | Top-1 Rate');
for (const [k, d] of Object.entries(aggregateSensitivity)) {
  console.log(
    k.padEnd(25) + ' | ' +
    d.exposureJain.mean.toFixed(4) + '   | ' +
    d.bookingJain.mean.toFixed(4) + '    | ' +
    d.workloadJain.mean.toFixed(4) + '   | ' +
    (d.top10Share.mean.toFixed(2) + '%').padEnd(8) + ' | ' +
    (d.exposureStarvation.mean.toFixed(2) + '%').padEnd(9) + ' | ' +
    (d.bookingStarvation.mean.toFixed(2) + '%').padEnd(10) + ' | ' +
    (d.top1DistanceKm.mean.toFixed(2) + ' km').padEnd(10) + ' | ' +
    d.top1Rating.mean.toFixed(2)
  );
}

console.log('\n=== TABLE VI: GEOGRAPHIC DEMAND CLUSTERING ROBUSTNESS (SCENARIOS A–D) ===');
for (const sc of CLUSTERING_SCENARIOS) {
  console.log(`\n--- ${sc.name} ---`);
  console.log('Algorithm'.padEnd(23) + ' | Exp Jain        | Exp Starv (%)   | Book Jain       | Workload Jain   | Top-1 Dist');
  for (const algoKey of ['nearest', 'nearest_least_loaded', 'fairmatch_v1', 'ablation_no_fairness']) {
    const d = aggregateClustering[sc.key].algorithms[algoKey];
    console.log(
      algoKey.padEnd(23) + ' | ' +
      d.exposureJain.formatted.padEnd(15) + ' | ' +
      d.exposureStarvation.formatted.padEnd(15) + ' | ' +
      d.bookingJain.formatted.padEnd(15) + ' | ' +
      d.workloadJain.formatted.padEnd(15) + ' | ' +
      d.top1DistanceKm.formatted
    );
  }
}

// Consistency Check
console.log('\nConsistency Verification:');
console.log('fairmatch_v1 Exposure Jain in Table II:          ', aggregateBaselines['fairmatch_v1'].exposureJain.mean);
console.log('fairmatch_v1 Exposure Jain in Table VI Scen A:   ', aggregateClustering['scenario_a'].algorithms['fairmatch_v1'].exposureJain.mean);
console.log('sensitivity_fair_10 Exposure Jain in Table IV:   ', aggregateSensitivity['sensitivity_fair_10'].exposureJain.mean);
console.log('100% Identical Across Tables:', (
  aggregateBaselines['fairmatch_v1'].exposureJain.mean === aggregateClustering['scenario_a'].algorithms['fairmatch_v1'].exposureJain.mean &&
  aggregateBaselines['fairmatch_v1'].exposureJain.mean === aggregateSensitivity['sensitivity_fair_10'].exposureJain.mean
));
