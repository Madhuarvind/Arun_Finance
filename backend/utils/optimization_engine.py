import pulp
from typing import List, Dict
from math import radians, cos, sin, asin, sqrt

class OptimizationEngine:
    """
    Advanced Mathematical Optimization for Finance Operations
    Supports Worker-Customer Assignment, Route Optimization, and Budgeting.
    """

    @staticmethod
    def haversine_distance(lat1, lon1, lat2, lon2):
        """Calculates distance between two points in km."""
        if None in [lat1, lon1, lat2, lon2]:
            return 999.0 # Penalty for missing coordinates
        
        # approximate radius of earth in km
        R = 6371.0
        
        dLat = radians(lat2 - lat1)
        dLon = radians(lon2 - lon1)
        lat1 = radians(lat1)
        lat2 = radians(lat2)

        a = sin(dLat / 2)**2 + cos(lat1) * cos(lat2) * sin(dLon / 2)**2
        c = 2 * asin(sqrt(a))
        return R * c

    @staticmethod
    def assign_workers_to_customers(workers: List[Dict], customers: List[Dict], max_per_worker: int = 50):
        """
        Solves the Worker-Customer Assignment problem using Integer Programming.
        Goal: Minimize total travel distance while balancing workload.
        """
        # 1. Define the Problem
        model = pulp.LpProblem("Worker_Assignment", pulp.LpMinimize)

        # 2. Decision Variables: x[w][c] = 1 if worker w is assigned customer c
        worker_ids = [str(w['id']) for w in workers]
        customer_ids = [str(c['id']) for c in customers]
        
        if not customer_ids:
            return [{"worker_id": int(w_id), "customer_ids": [], "count": 0} for w_id in worker_ids]
        
        x = pulp.LpVariable.dicts("assign", (worker_ids, customer_ids), 0, 1, cat=pulp.LpBinary)

        # 3. Objective Function: Minimize total distance
        distances = {}
        for w in workers:
            for c in customers:
                dist = OptimizationEngine.haversine_distance(
                    w.get('lat'), w.get('lng'),
                    c.get('lat'), c.get('lng')
                )
                distances[(str(w['id']), str(c['id']))] = dist
        
        model += pulp.lpSum([x[w_id][c_id] * distances[(w_id, c_id)] 
                            for w_id in worker_ids for c_id in customer_ids])

        # 4. Constraints
        # Rule A: Each customer must be assigned to exactly one worker
        for c_id in customer_ids:
            model += pulp.lpSum([x[w_id][c_id] for w_id in worker_ids]) == 1
        
        # Rule B: Workload balance (each worker has a max capacity)
        # Increasing max_per_worker if too many customers for feasibility
        limit = max(max_per_worker, (len(customers) // len(workers)) + 5)
        for w_id in worker_ids:
            model += pulp.lpSum([x[w_id][c_id] for c_id in customer_ids]) <= limit

        # 5. Solve
        model.solve(pulp.PULP_CBC_CMD(msg=0))

        # 6. Extract Results
        assignments = []
        if pulp.LpStatus[model.status] == 'Optimal':
            for w_id in worker_ids:
                assigned_custs = [int(c_id) for c_id in customer_ids if pulp.value(x[w_id][c_id]) == 1]
                assignments.append({
                    "worker_id": int(w_id),
                    "customer_ids": assigned_custs,
                    "count": len(assigned_custs)
                })
            return assignments
        
        # Fallback: Simple Round Robin if optimization fails
        assignments = [{"worker_id": int(w_id), "customer_ids": [], "count": 0} for w_id in worker_ids]
        for i, c_id in enumerate(customer_ids):
            assignments[i % len(workers)]["customer_ids"].append(int(c_id))
            assignments[i % len(workers)]["count"] += 1
        return assignments

    @staticmethod
    def optimize_budget(fund_limit: float, categories: List[Dict]):
        """
        suggests optimal fund allocation across categories to maximize ROI/Security.
        categories: list of {'id': 1, 'name': 'Gold Loan', 'roi': 12.0, 'risk_weight': 0.1}
        """
        model = pulp.LpProblem("Budget_Optimization", pulp.LpMaximize)
        
        # Decision Variables: amount[cat]
        cat_ids = [str(cat['id']) for cat in categories]
        amounts = pulp.LpVariable.dicts("allocate", cat_ids, 0, fund_limit, cat=pulp.LpContinuous)

        # Objective: Maximize Total Estimated Return (Weighted by Risk)
        # Return = Sum(amount * ROI * (1 - RiskWeight))
        model += pulp.lpSum([amounts[str(cat['id'])] * cat['roi'] * (1 - cat.get('risk_weight', 0.2)) 
                            for cat in categories])

        # Constraints
        # 1. Total allocation must not exceed fund limit
        model += pulp.lpSum([amounts[cid] for cid in cat_ids]) <= fund_limit

        # 2. Diversification: No category gets more than 50% of budget
        for cid in cat_ids:
             model += amounts[cid] <= fund_limit * 0.5

        model.solve(pulp.PULP_CBC_CMD(msg=0))

        if pulp.LpStatus[model.status] == 'Optimal':
            return {str(cat['id']): pulp.value(amounts[str(cat['id'])]) for cat in categories}
        
        return None
