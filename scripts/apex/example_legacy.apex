// using LEGACY Named Credentials
final HttpRequest req = new HttpRequest();
req.setEndpoint('callout:VictronEnergy/v2/users/me');
req.setHeader('Accept', 'application/json');
req.setHeader('X-Authorization', 'Bearer {!$Credential.OAuthToken}');
req.setMethod('GET');
final String body = new Http().send(req).getBody();
final Map<String,Object> data = (Map<String,Object>)JSON.deserializeUntyped(body);
System.debug('Users name is: ' + ((Map<String,Object>)data.get('user')).get('name'));
