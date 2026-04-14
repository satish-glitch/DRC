public class DRC_CustomLoginController {
    
    // Properties bound to the VF page inputs
    public String username { get; set; }
    public String password { get; set; }
    public String errorMessage { get; set; }
    public Boolean rememberMe { get; set; }
    
    // Constructor
    public DRC_CustomLoginController() {
        username = '';
        password = '';
        errorMessage = '';
        rememberMe = false;
    }
    
    // Login action method
    public PageReference login() {
        
        // Basic validation
        if (String.isBlank(username)) {
            errorMessage = 'Please enter your username.';
            return null;
        }
        
        if (String.isBlank(password)) {
            errorMessage = 'Please enter your password.';
            return null;
        }
        
        try {
            // Get the start URL (where to redirect after login)
            String startUrl = System.currentPageReference()
                                .getParameters()
                                .get('startURL');
            
            // If no startURL, default to home
            if (String.isBlank(startUrl)) {
                startUrl = '/';
            }
            
            // Salesforce Site login method
            PageReference ref = Site.login(username, password, startUrl);
            
            if (ref != null) {
                return ref; // Successful login → redirect
            } else {
                errorMessage = 'Invalid username or password. Please try again.';
                return null;
            }
            
        } catch (Exception e) {
            errorMessage = 'Login failed: ' + e.getMessage();
            return null;
        }
    }
    
    // Forgot password redirect
    public PageReference forgotPassword() {
        PageReference ref = new PageReference('/secur/forgotpassword.jsp');
        ref.setRedirect(true);
        return ref;
    }
}