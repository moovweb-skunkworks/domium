dommuim
=======

# Install Nokogiri
First Step is to install nokogiri. You can follow the steps here: http://nokogiri.org/tutorials/installing_nokogiri.html  
Nokogiri is required because we need to parse DOM in order to get these lists and check if there are ads on these pages! 
# Install Selenium! 
1. You can get the chrome driver [here](http://chromedriver.storage.googleapis.com/index.html)
2. Then you need to move it to your $PATH. I did this: `mv ~/Downloads/chromedriver /usr/local/bin`

# Gems to install:
1. gem install nokogiri 
2. gem install open-uri
3. gem install selenium-webdriver
4. gem install uri
5. gem install phantomjs
6. gem install text


# Brew installs
1. brew install phantomjs