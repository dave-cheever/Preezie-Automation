function parseJwt(token){
  if(!token) return {};
  var parts = token.split('.');
  if(parts.length < 2) return {};
  var payload = parts[1].replace(/-/g,'+').replace(/_/g,'/');
  switch(payload.length % 4){ case 2: payload += '=='; break; case 3: payload += '='; break; }
  var bytes = java.util.Base64.getDecoder().decode(payload);
  var json = new java.lang.String(bytes, 'UTF-8');
  return JSON.parse(json);
}

function isExpired(token, thresholdSeconds){
  var p = parseJwt(token);
  if(!p.exp) return true;
  var now = Math.floor(new Date().getTime()/1000);
  return (p.exp - now) <= (thresholdSeconds || 60); // refresh if within threshold (default 60s)
}

function getToken(){
  var token = karate.get('cmsToken');
  if(!token || isExpired(token, 60)){
    var res = karate.call('classpath:com/preezie/services/auth/get-token.feature');
    if(res && res.token){
      token = res.token;
      karate.set('cmsToken', token);
    } else {
      karate.log('token refresh failed, response:', res);
    }
  }
  return token;
}

function resetToken(){
  karate.set('cmsToken', null);
}

{ getToken: getToken, resetToken: resetToken }