import os
import random
import time
import requests
from flask import Flask, request, jsonify

# Create Flask app
app = Flask(__name__)

# Print configuration for debugging
print("=== API Service Configuration ===")
print(f"Service Name: {os.getenv('OTEL_SERVICE_NAME', 'api-service')}")
print(f"Scenario: {os.getenv('SCENARIO', 'default')}")
print(f"OTLP Endpoint: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'not set')}")
print(f"Git Commit SHA: {os.getenv('DD_GIT_COMMIT_SHA', 'not set')}")
print(f"Git Repository URL: {os.getenv('DD_GIT_REPOSITORY_URL', 'not set')}")
print("=================================")

# Mock data storage
users = []
user_counter = 1

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'api-service',
        'scenario': os.getenv('SCENARIO', 'default'),
        'version': '1.0.0'
    })

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users"""
    # Simulate some processing time
    time.sleep(random.uniform(0.1, 0.3))
    
    # Call database service to get user details
    try:
        database_url = os.getenv('DATABASE_SERVICE_URL', 'http://localhost:5002')
        response = requests.get(f'{database_url}/database/users', timeout=5)
        
        if response.status_code == 200:
            db_users = response.json()
            # Merge with local users
            all_users = users + db_users.get('users', [])
        else:
            all_users = users
            
    except Exception as e:
        print(f"Failed to fetch from database service: {e}")
        all_users = users
    
    return jsonify({
        'users': all_users,
        'count': len(all_users),
        'source': 'api-service'
    })

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    global user_counter
    
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({'error': 'Name is required'}), 400
    
    # Simulate processing time
    time.sleep(random.uniform(0.05, 0.2))
    
    # Create user
    user = {
        'id': user_counter,
        'name': data['name'],
        'email': data.get('email', ''),
        'created_at': time.time()
    }
    users.append(user)
    user_counter += 1
    
    # Also try to store in database service
    try:
        database_url = os.getenv('DATABASE_SERVICE_URL', 'http://localhost:5002')
        response = requests.post(f'{database_url}/database/users', json=user, timeout=5)
        
        if response.status_code == 200:
            print(f"User {user['id']} stored in database service")
        else:
            print(f"Failed to store user in database service: {response.status_code}")
            
    except Exception as e:
        print(f"Failed to call database service: {e}")
    
    return jsonify(user), 201

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user"""
    # Simulate processing time
    time.sleep(random.uniform(0.05, 0.15))
    
    user = next((u for u in users if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    return jsonify(user)

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Delete a user"""
    global users
    
    # Simulate processing time
    time.sleep(random.uniform(0.05, 0.15))
    
    user = next((u for u in users if u['id'] == user_id), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    users = [u for u in users if u['id'] != user_id]
    
    # Also try to delete from database service
    try:
        database_url = os.getenv('DATABASE_SERVICE_URL', 'http://localhost:5002')
        response = requests.delete(f'{database_url}/database/users/{user_id}', timeout=5)
        
        if response.status_code == 200:
            print(f"User {user_id} deleted from database service")
        else:
            print(f"Failed to delete user from database service: {response.status_code}")
            
    except Exception as e:
        print(f"Failed to call database service: {e}")
    
    return jsonify({'message': f'User {user_id} deleted'})

@app.route('/api/errors/test', methods=['GET'])
def test_errors():
    """Test various types of code-level errors for debugging and monitoring"""
    error_type = request.args.get('type', 'list')
    
    if error_type == 'list':
        return jsonify({
            'available_errors': [
                'division_by_zero',
                'null_pointer',
                'index_out_of_bounds',
                'type_error',
                'infinite_loop',
                'memory_error',
                'file_not_found',
                'json_decode_error',
                'network_timeout',
                'database_error',
                'validation_error',
                'custom_exception',
                'async_error'
            ],
            'usage': '/api/errors/test?type=<error_type>',
            'example': '/api/errors/test?type=division_by_zero'
        })
    
    return trigger_specific_error(error_type)

def trigger_specific_error(error_type):
    """Trigger specific types of errors for testing"""
    
    if error_type == 'division_by_zero':
        # Classic division by zero error
        result = 10 / 0
        return jsonify({'result': result})
    
    elif error_type == 'null_pointer':
        # Null/None reference error
        data = None
        result = data.get('key')  # This will raise AttributeError
        return jsonify({'result': result})
    
    elif error_type == 'index_out_of_bounds':
        # List index out of bounds
        my_list = [1, 2, 3]
        result = my_list[10]  # IndexError
        return jsonify({'result': result})
    
    elif error_type == 'type_error':
        # Type conversion error
        result = int("not_a_number")  # ValueError
        return jsonify({'result': result})
    
    elif error_type == 'infinite_loop':
        # Simulate infinite loop (with timeout protection)
        import signal
        def timeout_handler(signum, frame):
            raise TimeoutError("Loop execution timed out")
        
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(2)  # 2 second timeout
        
        try:
            counter = 0
            while True:  # This will timeout after 2 seconds
                counter += 1
                if counter > 1000000:  # Safety net
                    break
        finally:
            signal.alarm(0)
        
        return jsonify({'error': 'Infinite loop detected and stopped'})
    
    elif error_type == 'memory_error':
        # Simulate memory allocation error
        try:
            # Try to allocate a large amount of memory
            big_list = [0] * (10**8)  # This might cause MemoryError
            return jsonify({'result': 'Memory allocated successfully'})
        except MemoryError as e:
            raise MemoryError(f"Failed to allocate memory: {e}")
    
    elif error_type == 'file_not_found':
        # File system error
        with open('/nonexistent/path/file.txt', 'r') as f:
            content = f.read()
        return jsonify({'content': content})
    
    elif error_type == 'json_decode_error':
        # JSON parsing error
        import json
        invalid_json = '{"invalid": json, "missing": quotes}'
        parsed = json.loads(invalid_json)
        return jsonify({'parsed': parsed})
    
    elif error_type == 'network_timeout':
        # Network timeout simulation
        try:
            response = requests.get('http://httpbin.org/delay/10', timeout=1)
            return jsonify({'response': response.json()})
        except requests.exceptions.Timeout as e:
            raise requests.exceptions.Timeout(f"Network request timed out: {e}")
    
    elif error_type == 'database_error':
        # Database connection error
        try:
            # Try to connect to a non-existent database
            import sqlite3
            conn = sqlite3.connect('/nonexistent/database.db')
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM nonexistent_table")
            result = cursor.fetchall()
            return jsonify({'result': result})
        except Exception as e:
            raise Exception(f"Database operation failed: {e}")
    
    elif error_type == 'validation_error':
        # Custom validation error
        user_data = {'age': -5, 'email': 'invalid-email'}
        if user_data['age'] < 0:
            raise ValueError(f"Invalid age: {user_data['age']}. Age must be positive.")
        if '@' not in user_data['email']:
            raise ValueError(f"Invalid email format: {user_data['email']}")
    
    elif error_type == 'custom_exception':
        # Custom application exception
        class CustomApplicationError(Exception):
            def __init__(self, message, error_code):
                self.message = message
                self.error_code = error_code
                super().__init__(self.message)
        
        raise CustomApplicationError("This is a custom application error for testing", "APP_ERR_001")
    
    elif error_type == 'async_error':
        # Simulate async/threading related error
        import threading
        import time
        
        error_occurred = [False]
        
        def background_task():
            time.sleep(0.1)
            error_occurred[0] = True
            raise RuntimeError("Background task failed")
        
        thread = threading.Thread(target=background_task)
        thread.start()
        thread.join()
        
        if error_occurred[0]:
            raise RuntimeError("Async operation failed in background thread")
    
    else:
        # Unknown error type
        raise ValueError(f"Unknown error type: {error_type}. Use /api/errors/test to see available types.")

@app.route('/api/simulate-error', methods=['GET'])
def simulate_error():
    """Legacy error simulation endpoint - kept for backward compatibility"""
    error_type = request.args.get('type', 'generic')
    
    if error_type == 'timeout':
        time.sleep(2)  # Simulate timeout
        return jsonify({'error': 'Request timed out'}), 408
    elif error_type == 'server':
        return jsonify({'error': 'Internal server error'}), 500
    else:
        return jsonify({'error': 'Simulated error'}), 400

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    print(f"Starting API service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)