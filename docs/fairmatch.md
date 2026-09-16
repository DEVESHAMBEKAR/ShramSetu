# FairMatch — Transparent Multi-Factor Worker Matching & Ranking Architecture

> **Research & Technical Specification**  
> *ShramSetu AI-Powered Cooperative Gig Worker Service Marketplace*  
> *Algorithm Version*: `fairmatch_v1`  
> *Primary Author*: ShramSetu Engineering & Cooperative Architecture Working Group

---

## Important Research Disclaimer
> [!NOTE]
> **Transparent Weighted Ranking Model**:  
> The initial FairMatch implementation is an **explainable, deterministic multi-factor scoring and ranking model**. It is **not** claimed to be a trained deep neural network or black-box machine-learning model.
>
> Furthermore, **fairness must be measured, not merely assumed**: FairMatch incorporates recent workload and utilization as one weighted factor alongside skill, distance, availability, rating, and experience to provide a foundation for experimental evaluation against standard commercial baseline heuristics.

---

## 1. Problem Definition
Conventional gig platforms (e.g., Urban Company, TaskRabbit, Uber) rely on winner-take-all allocation algorithms that repeatedly dispatch tasks to a tiny percentile of "superstar" contractors. This causes:
1. **Severe Worker Burnout & Platform Churn**: A small cluster of workers is inundated while the vast majority remain underutilized.
2. **Artificial Scarcity & Longer Wait Times**: Customers experience extended delays waiting for high-demand workers located across town.
3. **Severe Cold-Start Inequity**: Newly onboarded skilled artisans struggle to receive their initial booking because platforms demand established reviews.
4. **Opacities & Algorithmic Anxiety**: Gig workers are subjected to opaque, unexplainable algorithmic penalties without transparent criteria.

---

## 2. Why Worker Matching is Needed
In a cooperative labor federation model such as ShramSetu, the matchmaking system must balance two equally critical goals:
- **Customer Utility**: Fast service delivery by verified, highly rated, proximal, and available professionals.
- **Worker Collective Welfare**: Equal opportunity, sustainable utilization, and fair distribution of cooperative dividends across the entire membership.

---

## 3. FairMatch Objective
FairMatch computes an explainable composite recommendation score $S_{\text{total}} \in [0.0, 1.0]$ for each eligible candidate, guaranteeing that proximity, technical skill competence, and quality are maintained while systematically countering superstar bias.

---

## 4. Eligibility Filter (Pre-Scoring Criteria)
Before entering the FairMatch scoring pipeline, every worker must strictly satisfy deterministic eligibility rules:
1. **Account Status**: `workers.worker_status = 'ACTIVE'` (KYC approved and federation certified).
2. **Availability**: `workers.is_available = true` (actively on-duty for on-demand dispatch).
3. **Verified Skill Match**: The worker must possess an officially verified credential in `public.worker_skills` corresponding to the requested `service_id`.
4. **Sanctions / Disciplinary Check**: Worker account must not be in `SUSPENDED` or `INACTIVE` state.

Candidates failing any of these criteria are filtered out before scoring.

---

## 5. Mathematical Formulation & Initial Weights

### Multi-Factor Scoring Formula
$$S_{\text{total}} = w_s \cdot S_{\text{skill}} + w_d \cdot S_{\text{dist}} + w_a \cdot S_{\text{avail}} + w_r \cdot S_{\text{rating}} + w_e \cdot S_{\text{exp}} + w_f \cdot S_{\text{fairness}}$$

### Configurable Experimental Weights
The initial experimental weights are configured centrally in `FairMatchWeights` and sum strictly to $1.0$:

| Factor | Weight ($w_i$) | Description |
|---|---|---|
| **Skill Compatibility ($S_{\text{skill}}$)** | `0.35` | Verified trade competence and specific specialization match |
| **Distance Score ($S_{\text{dist}}$)** | `0.20` | Geographic proximity calculated via Haversine formula |
| **Availability Score ($S_{\text{avail}}$)** | `0.15` | Immediate on-demand dispatch readiness |
| **Customer Rating ($S_{\text{rating}}$)** | `0.10` | Historical customer review score with cold-start correction |
| **Trade Experience ($S_{\text{exp}}$)** | `0.10` | Cumulative certified years in trade |
| **Fairness / Workload ($S_{\text{fairness}}$)** | `0.10` | Inverse recent workload (active and 7-day completed bookings) |
| **Total Sum** | **1.00** | Strictly validated at runtime ($\pm 10^{-6}$ tolerance) |

> [!TIP]
> These weights are **initial experimental baselines**, not permanent constants. The modular `FairMatchConfig` architecture enables researchers to vary weights and evaluate outcomes across controlled pilot cohorts.

---

## 6. Feature Normalization Strategies

Every feature $S_i$ is strictly normalized into the unit interval $[0.0, 1.0]$.

### 1. Skill Compatibility ($S_{\text{skill}}$)
- Verified trade match via `worker_skills`: $S_{\text{skill}} = 1.0$
- Related skill within trade category: $S_{\text{skill}} = 0.5$
- Unverified or unmatched skill: $S_{\text{skill}} = 0.0$ (excluded by eligibility filter)

### 2. Distance Score ($S_{\text{dist}}$)
Let $d$ be the geodesic distance in kilometers between customer coordinates $(lat_c, lng_c)$ and worker coordinates $(lat_w, lng_w)$ computed via the Haversine equation. Let $d_{\max} = 15.0\text{ km}$ represent the maximum service radius:
$$S_{\text{dist}} = \max\left(0.0, 1.0 - \frac{d}{d_{\max}}\right)$$
- $d = 0\text{ km} \implies S_{\text{dist}} = 1.0$
- $d = 7.5\text{ km} \implies S_{\text{dist}} = 0.5$
- $d \ge 15.0\text{ km} \implies S_{\text{dist}} = 0.0$
- **Missing Coordinates Fallback**: If customer or worker coordinates are unavailable, the system does not invent coordinates or set distance to zero. It applies a documented neutral baseline of $S_{\text{dist}} = 0.5$.

### 3. Availability Score ($S_{\text{avail}}$)
- Active duty & available: $S_{\text{avail}} = 1.0$
- Inactive / off-duty: $S_{\text{avail}} = 0.0$

### 4. Rating Score ($S_{\text{rating}}$) & Cold-Start Strategy
- For established workers with review count $N \ge 1$:
  $$S_{\text{rating}} = \frac{R - 1.0}{4.0}$$
  where $R \in [1.0, 5.0]$. ($5.0 \to 1.0, 4.0 \to 0.75, 3.0 \to 0.5, 1.0 \to 0.0$).
- **Cold-Start Rule**: If $N = 0$ (new cooperative artisan with zero customer reviews):
  The system **never** assigns an artificial 5.0 score. Instead, it assigns a **neutral score of $S_{\text{rating}} = 0.5$** (equivalent to 3.0 stars baseline). This eliminates the vicious cold-start barrier without misleading consumers.

### 5. Trade Experience Score ($S_{\text{exp}}$)
Let $E$ be certified trade experience in years (`experience_years`), benchmarked against a 10-year master artisan threshold ($E_{\max} = 10$):
$$S_{\text{exp}} = \min\left(1.0, \frac{E}{10.0}\right)$$
- $10+\text{ years} \implies 1.0$
- $5\text{ years} \implies 0.5$
- Missing experience fallback: $0.1$ (1 year baseline).

### 6. Fairness / Workload Score ($S_{\text{fairness}}$)
To distribute jobs sustainably, FairMatch calculates worker workload $W$ server-side:
$$W = (2 \times \text{active\_jobs}) + \text{completed\_jobs\_last\_7\_days}$$
Using a workload saturation threshold $W_{\max} = 10$:
$$S_{\text{fairness}} = \max\left(0.0, 1.0 - \frac{W}{W_{\max}}\right)$$
- Artisan with zero recent jobs ($W = 0$): $S_{\text{fairness}} = 1.0$ (maximum cooperative boost)
- Artisan with balanced load ($W = 5$): $S_{\text{fairness}} = 0.5$
- Artisan with heavy load ($W \ge 10$): $S_{\text{fairness}} = 0.0$

---

## 7. Deterministic Tie-Breaking
To guarantee reproducibility during research experiments, ties are resolved deterministically:
1. `totalScore` DESC
2. `skillScore` DESC
3. `distance` ASC
4. `worker_id` ASC (stable UUID comparison)

---

## 8. Comparative Research Baselines

To evaluate FairMatch rigorously, the engine implements 4 comparative algorithms over the identical candidate population:

```text
+-------------------+-------------------------------------------------------------+
| Algorithm ID      | Mathematical Formulation                                    |
+-------------------+-------------------------------------------------------------+
| nearest           | Score = S_dist                                              |
| highest_rated     | Score = S_rating                                            |
| rating_distance   | Score = 0.50 * S_rating + 0.50 * S_dist                     |
| fairmatch_v1      | Score = 0.35*Skill + 0.20*Dist + 0.15*Avail + 0.10*Rating    |
|                   |         + 0.10*Exp + 0.10*Fairness                          |
+-------------------+-------------------------------------------------------------+
```

---

## 9. System Architecture & Privacy Boundaries

```text
+-------------------------------------------------------------+
|               Customer Discovery Screen                     |
|  (Displays subtle "FairMatch Recommendation" reason tags)   |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|            ICustomerRepository / FairMatchService           |
+------------------------------+------------------------------+
                               |
                               v (Invokes RPC)
+-------------------------------------------------------------+
|    Supabase PostgreSQL RPC: `fairmatch_recommend_workers`   |
|                  [SECURITY DEFINER]                         |
|  • Filters eligible workers under RLS                       |
|  • Aggregates active + 7-day bookings privately             |
|  • Computes normalized features                             |
|  • Applies deterministic ranking & Top-N limit              |
|  • Logs match summary into `fairmatch_logs`                 |
+------------------------------+------------------------------+
                               |
                               v (Returns customer-safe JSON)
+-------------------------------------------------------------+
|           Customer-Visible Result (Zero PII Leak)           |
|  • Worker details (Name, Photo, Rating, Distance)           |
|  • Reasons: ['Verified Skill', 'Nearby', 'Available Now']   |
|  • NO cross-worker workload numbers or raw private scores   |
+-------------------------------------------------------------+
```

---

## 10. Research Evaluation Metrics

For future empirical evaluations, ShramSetu defines the following metrics:
1. **Workload Gini Coefficient ($G$)**:
   $$G = \frac{\sum_{i=1}^n \sum_{j=1}^n |w_i - w_j|}{2n^2 \bar{w}}$$
   Measures inequality of job assignments across the guild ($0.0 = \text{perfect equality}$).
2. **Workload Standard Deviation ($\sigma_w$)**: Spread of jobs per active worker over 30 days.
3. **Average Transit Distance ($\bar{d}$)**: Mean travel distance per fulfilled booking in km.
4. **Recommendation Acceptance Rate**: Proportion of top-ranked worker recommendations selected by customers.
5. **Ranking Latency ($T_{\text{exec}}$)**: Server-side execution time in milliseconds.

---

## 11. Graceful Failure Fallback
If the server-side FairMatch RPC encounters a network error or timeout:
1. The repository catches the exception non-blockingly.
2. The client executes local FairMatch scoring using cached/discovered candidates.
3. If local scoring fails, it seamlessly falls back to standard rating-sorted discovery.
4. The customer marketplace **never crashes or blocks**.