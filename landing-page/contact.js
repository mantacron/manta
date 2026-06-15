console.log('Manta contact script loaded');

function sendContactEmail() {
  console.log('sendContactEmail fired');

  var name    = document.getElementById('name').value.trim();
  var company = document.getElementById('company').value.trim();
  var email   = document.getElementById('email').value.trim();
  var team    = document.getElementById('team').value;
  var message = document.getElementById('message').value.trim();

  if (!name || !company || !email) {
    alert('Please fill in your name, company, and email.');
    return;
  }

  var subject = encodeURIComponent('Manta Enterprise Inquiry - ' + company);
  var body = encodeURIComponent(
    'Name:       ' + name    + '\n' +
    'Company:    ' + company + '\n' +
    'Email:      ' + email   + '\n' +
    'Team size:  ' + (team || 'not specified') + '\n\n' +
    'Message:\n' + message
  );

  var mailto = 'mailto:ray@mantacron.com?subject=' + subject + '&body=' + body;
  console.log('Opening:', mailto.substring(0, 80) + '...');
  location.href = mailto;
}
