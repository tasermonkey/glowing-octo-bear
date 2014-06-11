glowing-octo-bear
=================


Troubleshooting
===============
If you are having problems with logging in, check the `config.action_mailer.default_url_options` within config/environments/<env>.rb

    You should restart your application after changing Devise's
    configuration options. Otherwise you'll run into strange
    errors like users being unable to login and route helpers
    being undefined.

