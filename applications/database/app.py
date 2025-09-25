import os
import random
import time
import redis
from flask import Flask, request, jsonify

# Create Flask app
app = Flask(__name__)

# Print configuration for debugging
print("=== Database Service Configuration ===")
print(f"Service Name: {os.getenv('OTEL_SERVICE_NAME', 'database-service')}")
print(f"Scenario: {os.getenv('SCENARIO', 'default')}")
print(f"OTLP Endpoint: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'not set')}")
print(f"Git Commit SHA: {os.getenv('DD_GIT_COMMIT_SHA', 'not set')}")
print(f"Git Repository URL: {os.getenv('DD_GIT_REPOSITORY_URL', 'not set')}")
print("=======================================")

# Redis connection (optional - will fall back to in-memory if Redis not available)
redis_client = None
try:
    redis_host = os.getenv('REDIS_HOST', 'localhost')
    redis_port = int(os.getenv('REDIS_PORT', 6379))
    redis_client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True, socket_timeout=2)
    # Test connection
    redis_client.ping()
    print(f"Connected to Redis at {redis_host}:{redis_port}")
except Exception as e:
    print(f"Redis not available: {e}. Using in-memory storage.")
    redis_client = None

# In-memory fallback storage
memory_users = {}
memory_counter = 1

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    storage_type = "redis" if redis_client else "memory"
    return jsonify({
        'status': 'healthy',
        'service': 'database-service',
        'scenario': os.getenv('SCENARIO', 'default'),
        'version': '1.0.0',
        'storage': storage_type
    })

@app.route('/database/users', methods=['GET'])
def get_users():
    """Get all users from storage"""
    # Simulate database query time
    time.sleep(random.uniform(0.1, 0.4))
    
    try:
        if redis_client:
            # Get all user keys from Redis
            user_keys = redis_client.keys('user:*')
            users = []
            for key in user_keys:
                user_data = redis_client.hgetall(key)
                if user_data:
                    users.append({
                        'id': int(user_data.get('id', 0)),
                        'name': user_data.get('name', ''),
                        'email': user_data.get('email', ''),
                        'created_at': float(user_data.get('created_at', 0))
                    })
        else:
            users = list(memory_users.values())
        
        return jsonify({
            'users': users,
            'count': len(users),
            'source': 'database-service',
            'storage': 'redis' if redis_client else 'memory'
        })
    
    except Exception as e:
        print(f"Error fetching users: {e}")
        return jsonify({'error': 'Failed to fetch users'}), 500

@app.route('/database/users', methods=['POST'])
def create_user():
    """Store a new user"""
    global memory_counter
    
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({'error': 'Name is required'}), 400
    
    # Simulate database write time
    time.sleep(random.uniform(0.05, 0.2))
    
    try:
        user_id = data.get('id', memory_counter)
        user = {
            'id': user_id,
            'name': data['name'],
            'email': data.get('email', ''),
            'created_at': data.get('created_at', time.time())
        }
        
        if redis_client:
            # Store in Redis
            user_key = f"user:{user_id}"
            redis_client.hset(user_key, mapping=user)
            redis_client.expire(user_key, 3600)  # Expire after 1 hour
        else:
            # Store in memory
            memory_users[user_id] = user
            memory_counter = max(memory_counter, user_id) + 1
        
        return jsonify({
            'user': user,
            'storage': 'redis' if redis_client else 'memory'
        }), 201
    
    except Exception as e:
        print(f"Error creating user: {e}")
        return jsonify({'error': 'Failed to create user'}), 500

@app.route('/database/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user"""
    # Simulate database query time
    time.sleep(random.uniform(0.05, 0.2))
    
    try:
        if redis_client:
            user_key = f"user:{user_id}"
            user_data = redis_client.hgetall(user_key)
            if not user_data:
                return jsonify({'error': 'User not found'}), 404
            
            user = {
                'id': int(user_data.get('id', 0)),
                'name': user_data.get('name', ''),
                'email': user_data.get('email', ''),
                'created_at': float(user_data.get('created_at', 0))
            }
        else:
            user = memory_users.get(user_id)
            if not user:
                return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'user': user,
            'storage': 'redis' if redis_client else 'memory'
        })
    
    except Exception as e:
        print(f"Error fetching user {user_id}: {e}")
        return jsonify({'error': 'Failed to fetch user'}), 500

@app.route('/database/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Delete a user"""
    # Simulate database operation time
    time.sleep(random.uniform(0.05, 0.2))
    
    try:
        if redis_client:
            user_key = f"user:{user_id}"
            if not redis_client.exists(user_key):
                return jsonify({'error': 'User not found'}), 404
            redis_client.delete(user_key)
        else:
            if user_id not in memory_users:
                return jsonify({'error': 'User not found'}), 404
            del memory_users[user_id]
        
        return jsonify({
            'message': f'User {user_id} deleted',
            'storage': 'redis' if redis_client else 'memory'
        })
    
    except Exception as e:
        print(f"Error deleting user {user_id}: {e}")
        return jsonify({'error': 'Failed to delete user'}), 500

@app.route('/database/simulate-slow-query', methods=['GET'])
def simulate_slow_query():
    """Simulate a slow database query"""
    duration = float(request.args.get('duration', 1.0))
    time.sleep(duration)
    
    return jsonify({
        'message': f'Slow query completed in {duration} seconds',
        'storage': 'redis' if redis_client else 'memory'
    })

@app.route('/database/stats', methods=['GET'])
def get_stats():
    """Get database statistics"""
    try:
        if redis_client:
            user_keys = redis_client.keys('user:*')
            stats = {
                'total_users': len(user_keys),
                'storage': 'redis',
                'redis_info': {
                    'used_memory': redis_client.info().get('used_memory_human', 'N/A'),
                    'connected_clients': redis_client.info().get('connected_clients', 0)
                }
            }
        else:
            stats = {
                'total_users': len(memory_users),
                'storage': 'memory',
                'memory_info': {
                    'user_count': len(memory_users)
                }
            }
        
        return jsonify(stats)
    
    except Exception as e:
        print(f"Error getting stats: {e}")
        return jsonify({'error': 'Failed to get stats'}), 500

@app.route('/database/errors/test', methods=['GET'])
def test_database_errors():
    """Test various types of database-specific errors for debugging and monitoring"""
    error_type = request.args.get('type', 'list')
    
    if error_type == 'list':
        return jsonify({
            'available_errors': [
                'redis_connection_error',
                'redis_timeout',
                'redis_memory_error',
                'data_corruption',
                'serialization_error',
                'key_not_found',
                'transaction_rollback',
                'connection_pool_exhausted',
                'disk_full',
                'permission_denied'
            ],
            'usage': '/database/errors/test?type=<error_type>',
            'example': '/database/errors/test?type=redis_connection_error'
        })
    
    return trigger_database_error(error_type)

def trigger_database_error(error_type):
    """Trigger specific database-related errors for testing"""
    
    if error_type == 'redis_connection_error':
        # Simulate Redis connection failure
        import redis
        fake_redis = redis.Redis(host='nonexistent-redis-host', port=6379, db=0)
        fake_redis.ping()  # This will raise ConnectionError
        return jsonify({'result': 'Redis connected'})
    
    elif error_type == 'redis_timeout':
        # Simulate Redis timeout
        if redis_client:
            # Try to execute a command that would timeout
            redis_client.execute_command('DEBUG', 'SLEEP', '10')  # Sleep for 10 seconds
        else:
            raise TimeoutError("Redis timeout simulation - Redis not available")
        return jsonify({'result': 'Redis operation completed'})
    
    elif error_type == 'redis_memory_error':
        # Simulate Redis out of memory
        if redis_client:
            try:
                # Try to store a very large value
                large_value = 'x' * (100 * 1024 * 1024)  # 100MB string
                redis_client.set('large_key', large_value)
                return jsonify({'result': 'Large value stored'})
            except Exception as e:
                raise MemoryError(f"Redis memory error: {e}")
        else:
            raise MemoryError("Redis memory error simulation - Redis not available")
    
    elif error_type == 'data_corruption':
        # Simulate data corruption detection
        if redis_client:
            # Store corrupted data
            redis_client.set('corrupted_user', 'invalid:json:data:structure')
            # Try to retrieve and parse
            corrupted_data = redis_client.get('corrupted_user')
            import json
            parsed_data = json.loads(corrupted_data)  # This will fail
            return jsonify({'data': parsed_data})
        else:
            raise ValueError("Data corruption detected in user data")
    
    elif error_type == 'serialization_error':
        # Simulate serialization/deserialization error
        import pickle
        import io
        
        # Create an object that can't be serialized
        class UnserializableObject:
            def __init__(self):
                self.file_handle = open('/dev/null', 'r')
        
        obj = UnserializableObject()
        serialized = pickle.dumps(obj)  # This will raise TypeError
        return jsonify({'result': 'Object serialized'})
    
    elif error_type == 'key_not_found':
        # Simulate critical key not found
        if redis_client:
            critical_data = redis_client.get('critical_config_key')
            if critical_data is None:
                raise KeyError("Critical configuration key 'critical_config_key' not found in database")
        else:
            raise KeyError("Critical key not found - Redis not available")
        return jsonify({'data': critical_data})
    
    elif error_type == 'transaction_rollback':
        # Simulate transaction rollback scenario
        if redis_client:
            pipe = redis_client.pipeline()
            try:
                pipe.multi()
                pipe.set('tx_key1', 'value1')
                pipe.set('tx_key2', 'value2')
                # Simulate an error in the middle of transaction
                raise Exception("Transaction failed at step 2")
                pipe.execute()
            except Exception as e:
                pipe.reset()  # Rollback
                raise RuntimeError(f"Transaction rolled back due to error: {e}")
        else:
            raise RuntimeError("Transaction rollback simulation - Redis not available")
    
    elif error_type == 'connection_pool_exhausted':
        # Simulate connection pool exhaustion
        import redis.connection
        raise redis.connection.ConnectionError("Connection pool exhausted - all connections in use")
    
    elif error_type == 'disk_full':
        # Simulate disk full error
        import errno
        raise OSError(errno.ENOSPC, "No space left on device - cannot write to database")
    
    elif error_type == 'permission_denied':
        # Simulate permission denied error
        import errno
        raise PermissionError(errno.EACCES, "Permission denied - cannot access database files")
    
    else:
        # Unknown error type
        raise ValueError(f"Unknown database error type: {error_type}. Use /database/errors/test to see available types.")

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5002))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    print(f"Starting database service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)