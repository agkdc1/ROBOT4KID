/* NL2Bot Planning Server — shared JS utilities */

// Auth helper
function getAuthHeaders() {
    const token = localStorage.getItem('token');
    return {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    };
}

// Redirect to login if unauthorized
async function authFetch(url, options = {}) {
    options.headers = { ...getAuthHeaders(), ...options.headers };
    const res = await fetch(url, options);
    if (res.status === 401) {
        localStorage.removeItem('token');
        window.location.href = '/login';
        return null;
    }
    return res;
}
