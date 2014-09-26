#!/usr/bin/env ruby -wKU

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'net/http'
require "selenium-webdriver"
require 'csv'
require 'text'

IPHONE_USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X; en-us) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53'

class Domium

  def initialize(sites=[])
    
  end

  def make_5000_best_page_url(page_number)
    "http://5000best.com/?w.c&xml=1&ta=32&p=#{page_number}&sortby=0&ise=&h=03"
  end

  def parse_best_page(page_number)
    page_url = self.make_5000_best_page_url page_number

    page = Nokogiri::HTML(open(page_url, :read_timeout=>5*60))

    table_links = page.xpath(".//table[@id='ttable']//tr")

    sites = []
    table_links.each do |link|
      category = link.xpath("./td/a[contains(@href, '/websites/')]")[0].text
      url      = link.xpath("./td/a[@rel='nofollow']")[0]['href']
      url += "/" if url[-1] != "/" 
      unless url.index("www")
        url.include?("https") ? insert_at = 8 : insert_at = 7
        url = url.insert(insert_at, "www.")
      end
      rank     = link.xpath("./td[1]")[0].text.chomp(".")
      sites.push({category: category, url: url, rank: rank})
    end

    return sites
  end

  def parse_best_pages(range=1..50)
    sites = []
    range.each do |i|
      sites += self.parse_best_page i
    end
    sites 
  end

  def is_mobile?(url_query)
    url    = URI.parse(url_query)
    response = get_mobile_response_for(url)
    page = Nokogiri::HTML(response.body)

    redirects = false
    redirects = self.has_serverside_mobile_redirect? response
    unless redirects
      cs_redirects = self.has_clientside_modile_redirect? url
    end

    mobile_redirect = (redirects || cs_redirects)

    responsive = false
    responsive_delivery = false
    unless mobile_redirect
      responsive = self.is_responsive? response, url_query, page
      unless responsive
        responsive_delivery = has_responsive_delivery? url_query
      end
    end

    # puts "\n URL: #{url_query}\n mobile_redirect: #{(redirects || cs_redirects)}\n responsive: #{responsive}"
    return { mobile_redirect: mobile_redirect, 
             responsive: responsive, 
             responsive_delivery: responsive_delivery
           }
  end

  def has_ad?(url_query)
    url           = URI.parse(url_query)
    response      = get_mobile_response_for(url)
    page          = Nokogiri::HTML(response.body)
    adwords       = page.xpath("//script[not(@src)]")
    has_google_ad = false

    adwords.each do |ad|
      if(ad.text.include?('google_ad') || ad.text.include?('google_conversion'))
        has_google_ad = true
        break
      end
    end

    google_ad_script = page.xpath("//script[contains(@src, 'googlead')]")

    if google_ad_script.length > 0
      has_google_ad = true
    end
    return {has_google_ad: has_google_ad}
  end

  def is_mobile_url?(url)
    return true  if url.include? 'm.'
    return true  if url.include? 'mobile'
    return true  if url.include? '/m/'
    return false
  end

  def has_serverside_mobile_redirect?(response)
    return false unless response['Location']
    return is_mobile_url? response['Location']
  end

  def has_clientside_modile_redirect?(url)
    begin
      capabilities = Selenium::WebDriver::Remote::Capabilities.phantomjs('phantomjs.page.settings.userAgent' => IPHONE_USER_AGENT)

      driver = Selenium::WebDriver.for :phantomjs, :desired_capabilities => capabilities
      # driver = Selenium::WebDriver.for :chrome, switches: %W[--user-agent=#{IPHONE_USER_AGENT}]
      driver.manage.window.resize_to(320, 536)
      driver.navigate.to url
      page_url = driver.execute_script("return window.location.host + window.location.path")
      driver.quit
      return is_mobile_url? page_url      
    rescue 
      return false
    end
  end

  def has_responsive_delivery?(url_query)
    url              = URI.parse(url_query)
    response         = get_mobile_response_for  url
    desktop_response = get_desktop_response_for url

    white = Text::WhiteSimilarity.new

    sim = white.similarity response.body, desktop_response.body
    puts "similarity is: #{sim}"
    if sim < 0.8
      responsive_delivery = true
    else
      responsive_delivery = false
    end

    return responsive_delivery
  end


  def get_mobile_response_for(url)
    path = url.path
    path ||= "/"
    req  = Net::HTTP::Get.new(path, {'User-Agent' => IPHONE_USER_AGENT})
    # req.use_ssl = true
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      response = http.request(req)
      return response

    rescue
      url.scheme = "https"
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
      return response
    end
  end

  def get_desktop_response_for(url)
    path   = url.path
    path ||= "/"
    req = Net::HTTP::Get.new(path, {'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36'})
    response = Net::HTTP.start( url.host, url.port ) { |http| http.request( req ) }
    return response
  end


  def is_responsive?(response, url_query, page)
    stylesheets = page.xpath(".//link[@rel='stylesheet']")
    responsive = false
    stylesheets.each do |css|
      return true if css["media"] && css["media"].include?('width')
      if css["href"].length > 1
        to_check = css["href"]
        need_to_add = true
        to_check.match(/^(?:[a-z]+:)?\/\//i){|m| need_to_add = false }

        if need_to_add
          to_check.prepend(url_query)
        end

        url = URI.parse(to_check)
        
        response = get_mobile_response_for(url)
        responsive = response.body.include? '@media' if response.body.include? '@media'  
        return true if responsive
      end
    end
    return responsive
  end

  def to_csv_string(range=1..50)
    sites = parse_best_pages(range)
    has_inserted_keys = false

    generated_csv = ""
    sites.each do |site|
      testing_url = site[:url]
      puts "testing_url='#{testing_url}'"
      site.merge!(self.is_mobile? testing_url)
      site.merge!(self.has_ad?    testing_url)
      unless has_inserted_keys
        has_inserted_keys = true
        generated_csv += site.keys.to_csv
      end
      puts "site=#{site}"
      puts "csv=#{generated_csv}"
      generated_csv += site.values.to_csv
    end
    puts generated_csv
    return generated_csv
  end

  def to_csv(range=1..50, filename="processed_file.csv")
    generated_csv = self.to_csv_string(range)
    new_csv = File.open("output/#{filename}", "w+") { |file|
      file << generated_csv
    }
  end

end