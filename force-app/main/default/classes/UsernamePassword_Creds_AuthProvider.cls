public class UsernamePassword_Creds_AuthProvider extends Auth.AuthProviderPluginClass {
    // constants
    public static final String CUSTOM_METADATA_TYPE = 'UsernamePassword_Credentials__mdt';
    public static final String AUTH_PROVIDER_NAME = 'UsernamePassword_Credentials';

    // declarations
    private IRefreshTokenGenerator generator = new DefaultRefreshTokenGenerator();

    public UsernamePassword_Creds_AuthProvider() {
    }
    public UsernamePassword_Creds_AuthProvider(IRefreshTokenGenerator gen) {
        this.generator = gen;
    }

    public String getCustomMetadataType() {
        return CUSTOM_METADATA_TYPE;
    }

    public PageReference initiate(Map<String, String> authProviderConfiguration, String stateToPropagate) {
        final String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        final String url = baseUrl + authProviderConfiguration.get('Callback_URL__c') + '?state=' + stateToPropagate;
        System.debug('initiate called - url <' + url + '>');
        return new PageReference(url);
    }

    public Auth.AuthProviderTokenResponse handleCallback(
        Map<String, String> config,
        Auth.AuthProviderCallbackState callbackState
    ) {
        // get access token
        final String access_token = this.retrieveToken(config);
        final String refresh_token = this.generateRefreshToken();
        final String state = callbackState.queryParameters.get('state');
        return new Auth.AuthProviderTokenResponse(AUTH_PROVIDER_NAME, access_token, refresh_token, state);
    }

    public Auth.UserData getUserInfo(
        Map<String, String> authProviderConfiguration,
        Auth.AuthProviderTokenResponse response
    ) {
        // get userinfo
        final Http h = new Http();
        final HttpRequest req = new HttpRequest();
        req.setEndpoint('https://vrmapi.victronenergy.com/v2/users/me');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-authorization', 'Bearer ' + response.oauthToken);
        req.setMethod('GET');
        final HttpResponse resUserinfo = h.send(req);
        
        // get name
        final Map<String, Object> userinfo = (Map<String, Object>) JSON.deserializeUntyped(resUserinfo.getBody());
        final Map<String, Object> user = (Map<String,Object>)userinfo.get('user');
        final String name = (String)user.get('name');

        // return
        return new Auth.UserData(
            null,
            null,
            null,
            null,
            null,
            null,
            name,
            null,
            AUTH_PROVIDER_NAME,
            null,
            new Map<String, String>()
        );
    }

    public override Auth.OAuthRefreshResult refresh(Map<String, String> config, String refreshToken) {
        // generate dummy refresh token and get new access token
        final String newRefreshToken = this.generateRefreshToken();
        final String accessToken = this.retrieveToken(config);
        return new Auth.OAuthRefreshResult(accessToken, newRefreshToken);
    }

    private String retrieveToken(Map<String, String> config) {
        final String tokenEndpoint = 'https://vrmapi.victronenergy.com/v2/auth/login';
        final String body =
            '{"username": "' +
            get(config, 'Username__c') +
            '", "password": "' +
            get(config, 'Password__c') + 
            '"}';
        System.debug('Token endpoint <' + tokenEndpoint + '>');
        System.debug('Body <' + body + '>');

        // setup request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(body);

        // execute requets
        Http h = new Http();
        HttpResponse res = h.send(req);

        // get token from response
        return this.getTokenFromHttpResponse(res);
    }

    /**
     * Get the access_token from Http response.
     *
     */
    private String getTokenFromHttpResponse(HttpResponse res) {
        final Integer responseCode = res.getStatusCode();
        if (responseCode != 200) {
            throw new UsernamePassword_Creds_Exception();
        }
        final Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken =  (String) data.get('token');
        
        // return
        return accessToken;
    }

    private String getAndEncode(Map<String, String> config, String key) {
        return EncodingUtil.urlEncode(this.get(config, key), 'UTF-8');
    }

    private String get(Map<String, String> config, String key) {
        return config.get(key);
    }

    private String generateRefreshToken() {
        return this.generator.generate();
    }

    public class UsernamePassword_Creds_Exception extends Exception {
        
    }

    /**
     * Interface to allow us to override refresh token generation when testing.
     */
    public interface IRefreshTokenGenerator {
        String generate();
    }

    /**
     * Default implementation for runtime.
     */
    public class DefaultRefreshTokenGenerator implements IRefreshTokenGenerator {
        public String generate() {
            final String refreshToken = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
            return refreshToken;
        }
    }
}
