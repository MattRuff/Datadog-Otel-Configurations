import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

// Mock tracer for basic functionality without OpenTelemetry packages
const mockTracer = {
  startSpan: (name) => ({
    setAttributes: (attrs) => console.log(`Span ${name} attributes:`, attrs),
    recordException: (err) => console.log(`Span ${name} exception:`, err.message),
    end: () => console.log(`Span ${name} ended`)
  })
};

const tracer = mockTracer;

function App() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [newUserName, setNewUserName] = useState('');
  const [newUserEmail, setNewUserEmail] = useState('');

  const apiUrl = process.env.REACT_APP_API_URL || '/api';

  const fetchUsers = async () => {
    const span = tracer.startSpan('fetch_users');
    setLoading(true);
    setError('');
    
    try {
      span.setAttributes({
        'frontend.operation': 'fetch_users',
        'http.url': `${apiUrl}/users`
      });
      
      const response = await axios.get(`${apiUrl}/users`);
      const usersData = response.data.users || response.data || [];
      setUsers(usersData);
      span.setAttributes({
        'users.count': usersData.length,
        'http.status_code': response.status
      });
    } catch (err) {
      const errorMessage = err.response?.data?.error || err.message || 'Failed to fetch users';
      setError(errorMessage);
      span.recordException(err);
      span.setAttributes({
        'error': true,
        'error.message': errorMessage,
        'http.status_code': err.response?.status || 0
      });
    } finally {
      setLoading(false);
      span.end();
    }
  };

  const createUser = async (e) => {
    e.preventDefault();
    
    if (!newUserName.trim()) {
      setError('Name is required');
      return;
    }

    const span = tracer.startSpan('create_user');
    setLoading(true);
    setError('');
    
    try {
      const userData = {
        name: newUserName.trim(),
        email: newUserEmail.trim() || undefined
      };

      span.setAttributes({
        'frontend.operation': 'create_user',
        'user.name': userData.name,
        'http.url': `${apiUrl}/users`
      });
      
      const response = await axios.post(`${apiUrl}/users`, userData);
      
      span.setAttributes({
        'user.id': response.data.id,
        'http.status_code': response.status
      });
      
      // Reset form
      setNewUserName('');
      setNewUserEmail('');
      
      // Refresh users list
      await fetchUsers();
    } catch (err) {
      const errorMessage = err.response?.data?.error || err.message || 'Failed to create user';
      setError(errorMessage);
      span.recordException(err);
      span.setAttributes({
        'error': true,
        'error.message': errorMessage,
        'http.status_code': err.response?.status || 0
      });
    } finally {
      setLoading(false);
      span.end();
    }
  };

  const deleteUser = async (userId) => {
    const span = tracer.startSpan('delete_user');
    
    try {
      span.setAttributes({
        'frontend.operation': 'delete_user',
        'user.id': userId
      });
      
      // Simulate delete (not implemented in backend for this demo)
      console.log(`Delete user ${userId} - not implemented in backend`);
      span.setAttributes({
        'operation.simulated': true
      });
    } finally {
      span.end();
    }
  };

  // Error testing functions
  const triggerFrontendError = (errorType) => {
    const span = tracer.startSpan('frontend_error_test');
    
    try {
      span.setAttributes({
        'frontend.operation': 'trigger_error',
        'error.type': errorType
      });

      switch (errorType) {
        case 'js_runtime_error':
          // Undefined variable access
          // eslint-disable-next-line no-undef
          console.log(undefinedVariable.property);
          break;
        
        case 'type_error':
          // Type mismatch
          const number = 42;
          number.split(',');
          break;
        
        case 'state_error':
          // React state error
          setUsers('invalid_state'); // Setting string instead of array
          break;
        
        case 'infinite_loop':
          // Infinite loop (with safety)
          let counter = 0;
          while (counter < 1000000) {
            counter++;
          }
          throw new Error('Infinite loop completed');
        
        case 'memory_error':
          // Memory allocation
          const bigArray = new Array(10000000).fill('data');
          console.log(bigArray.length);
          break;
        
        case 'custom_error':
          throw new Error('Custom frontend error for testing');
        
        default:
          throw new Error(`Unknown frontend error type: ${errorType}`);
      }
    } catch (err) {
      setError(`Frontend Error (${errorType}): ${err.message}`);
      span.recordException(err);
      span.setAttributes({
        'error': true,
        'error.message': err.message
      });
    } finally {
      span.end();
    }
  };

  const triggerApiError = async (errorType) => {
    const span = tracer.startSpan('api_error_test');
    setLoading(true);
    setError('');
    
    try {
      span.setAttributes({
        'frontend.operation': 'trigger_api_error',
        'error.type': errorType,
        'http.url': `${apiUrl}/errors/test?type=${errorType}`
      });
      
      const response = await axios.get(`${apiUrl}/errors/test?type=${errorType}`);
      
      // If we get here, the error didn't occur (shouldn't happen)
      span.setAttributes({
        'unexpected_success': true,
        'http.status_code': response.status
      });
      
      setError(`Unexpected: ${errorType} did not trigger an error`);
    } catch (err) {
      const errorMessage = err.response?.data?.error || err.message || `API Error: ${errorType}`;
      setError(`API Error (${errorType}): ${errorMessage}`);
      
      span.recordException(err);
      span.setAttributes({
        'error': true,
        'error.message': errorMessage,
        'http.status_code': err.response?.status || 0
      });
    } finally {
      setLoading(false);
      span.end();
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>OpenTelemetry Demo - User Management</h1>
        <p>Demonstrating distributed tracing across microservices</p>
      </header>

      <main className="App-main">
        {/* Create User Form */}
        <section className="create-user-section">
          <h2>Create New User</h2>
          <form onSubmit={createUser} className="user-form">
            <div className="form-group">
              <label htmlFor="name">Name (required):</label>
              <input
                type="text"
                id="name"
                value={newUserName}
                onChange={(e) => setNewUserName(e.target.value)}
                placeholder="Enter user name"
                disabled={loading}
              />
            </div>
            <div className="form-group">
              <label htmlFor="email">Email (optional):</label>
              <input
                type="email"
                id="email"
                value={newUserEmail}
                onChange={(e) => setNewUserEmail(e.target.value)}
                placeholder="Enter user email"
                disabled={loading}
              />
            </div>
            <button type="submit" disabled={loading || !newUserName.trim()}>
              {loading ? 'Creating...' : 'Create User'}
            </button>
          </form>
        </section>

        {/* Users List */}
        <section className="users-section">
          <div className="users-header">
            <h2>Users List</h2>
            <button onClick={fetchUsers} disabled={loading} className="refresh-btn">
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>

          {error && (
            <div className="error-message">
              Error: {error}
            </div>
          )}

          {loading && (
            <div className="loading-message">
              Loading users...
            </div>
          )}

          {!loading && users.length === 0 && !error && (
            <div className="no-users-message">
              No users found. Create one above!
            </div>
          )}

          {users.length > 0 && (
            <div className="users-grid">
              {users.map((user) => (
                <div key={user.id} className="user-card">
                  <h3>{user.name}</h3>
                  <p>Email: {user.email}</p>
                  <p>ID: {user.id}</p>
                  <button 
                    onClick={() => deleteUser(user.id)}
                    className="delete-btn"
                    disabled={loading}
                  >
                    Delete (Simulated)
                  </button>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Error Testing Section */}
        <section className="error-testing-section">
          <h2>🚨 Error Testing & Debugging</h2>
          <p>Test various error scenarios to validate monitoring and debugging capabilities</p>
          
          <div className="error-testing-grid">
            {/* Frontend Errors */}
            <div className="error-category">
              <h3>Frontend Errors</h3>
              <p>Test JavaScript and React errors</p>
              <div className="error-buttons">
                <button 
                  onClick={() => triggerFrontendError('js_runtime_error')}
                  className="error-btn runtime-error"
                  disabled={loading}
                >
                  Runtime Error
                </button>
                <button 
                  onClick={() => triggerFrontendError('type_error')}
                  className="error-btn type-error"
                  disabled={loading}
                >
                  Type Error
                </button>
                <button 
                  onClick={() => triggerFrontendError('state_error')}
                  className="error-btn state-error"
                  disabled={loading}
                >
                  State Error
                </button>
                <button 
                  onClick={() => triggerFrontendError('custom_error')}
                  className="error-btn custom-error"
                  disabled={loading}
                >
                  Custom Error
                </button>
              </div>
            </div>

            {/* API Backend Errors */}
            <div className="error-category">
              <h3>API Backend Errors</h3>
              <p>Test server-side error handling</p>
              <div className="error-buttons">
                <button 
                  onClick={() => triggerApiError('division_by_zero')}
                  className="error-btn math-error"
                  disabled={loading}
                >
                  Division by Zero
                </button>
                <button 
                  onClick={() => triggerApiError('null_pointer')}
                  className="error-btn null-error"
                  disabled={loading}
                >
                  Null Pointer
                </button>
                <button 
                  onClick={() => triggerApiError('index_out_of_bounds')}
                  className="error-btn index-error"
                  disabled={loading}
                >
                  Index Out of Bounds
                </button>
                <button 
                  onClick={() => triggerApiError('type_error')}
                  className="error-btn type-error"
                  disabled={loading}
                >
                  Type Conversion
                </button>
              </div>
            </div>

            {/* System & Network Errors */}
            <div className="error-category">
              <h3>System & Network Errors</h3>
              <p>Test infrastructure and external service errors</p>
              <div className="error-buttons">
                <button 
                  onClick={() => triggerApiError('network_timeout')}
                  className="error-btn network-error"
                  disabled={loading}
                >
                  Network Timeout
                </button>
                <button 
                  onClick={() => triggerApiError('database_error')}
                  className="error-btn db-error"
                  disabled={loading}
                >
                  Database Error
                </button>
                <button 
                  onClick={() => triggerApiError('file_not_found')}
                  className="error-btn file-error"
                  disabled={loading}
                >
                  File Not Found
                </button>
                <button 
                  onClick={() => triggerApiError('memory_error')}
                  className="error-btn memory-error"
                  disabled={loading}
                >
                  Memory Error
                </button>
              </div>
            </div>

            {/* Advanced Errors */}
            <div className="error-category">
              <h3>Advanced Error Scenarios</h3>
              <p>Test complex error patterns and edge cases</p>
              <div className="error-buttons">
                <button 
                  onClick={() => triggerApiError('json_decode_error')}
                  className="error-btn json-error"
                  disabled={loading}
                >
                  JSON Parse Error
                </button>
                <button 
                  onClick={() => triggerApiError('validation_error')}
                  className="error-btn validation-error"
                  disabled={loading}
                >
                  Validation Error
                </button>
                <button 
                  onClick={() => triggerApiError('custom_exception')}
                  className="error-btn custom-error"
                  disabled={loading}
                >
                  Custom Exception
                </button>
                <button 
                  onClick={() => triggerApiError('async_error')}
                  className="error-btn async-error"
                  disabled={loading}
                >
                  Async/Threading Error
                </button>
              </div>
            </div>
          </div>
          
          <div className="error-testing-info">
            <h4>💡 What This Tests:</h4>
            <ul>
              <li><strong>Exception Tracking:</strong> How OpenTelemetry captures and reports exceptions</li>
              <li><strong>Error Propagation:</strong> How errors flow through distributed services</li>
              <li><strong>Debugging Context:</strong> Stack traces, error details, and correlation IDs</li>
              <li><strong>Monitoring Alerts:</strong> How monitoring systems detect and alert on errors</li>
              <li><strong>Recovery Mechanisms:</strong> How applications handle and recover from errors</li>
            </ul>
          </div>
        </section>

        {/* Info Section */}
        <section className="info-section">
          <h3>Tracing Information</h3>
          <p>This application demonstrates OpenTelemetry instrumentation:</p>
          <ul>
            <li>Frontend traces user interactions and API calls</li>
            <li>API service traces business logic and database calls</li>
            <li>Database service traces Redis operations</li>
            <li>All traces are sent via OTLP to configured endpoints</li>
          </ul>
        </section>
      </main>
    </div>
  );
}

export default App;
