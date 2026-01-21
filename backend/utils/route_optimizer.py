import math

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Haversine formula to calculate distance between two GPS points in km
    """
    if None in [lat1, lon1, lat2, lon2]:
        return float('inf')
        
    R = 6371  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) * math.sin(dlat / 2) +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) * math.sin(dlon / 2))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def optimize_route(start_lat, start_lon, customers):
    """
    Greedy Nearest Neighbor algorithm to sort customers by proximity.
    'customers' is a list of dicts with 'latitude' and 'longitude'.
    """
    if not customers:
        return []
        
    unvisited = customers[:]
    optimized_path = []
    
    current_lat = start_lat
    current_lon = start_lon
    
    while unvisited:
        # Filter out customers without GPS
        nearest_customer = None
        min_dist = float('inf')
        
        for cust in unvisited:
            dist = calculate_distance(current_lat, current_lon, cust.get('latitude'), cust.get('longitude'))
            if dist < min_dist:
                min_dist = dist
                nearest_customer = cust
        
        if nearest_customer:
            optimized_path.append(nearest_customer)
            unvisited.remove(nearest_customer)
            current_lat = nearest_customer.get('latitude')
            current_lon = nearest_customer.get('longitude')
        else:
            # If remaining customers have no GPS, just append them
            optimized_path.extend(unvisited)
            break
            
    return optimized_path
