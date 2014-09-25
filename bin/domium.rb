#!/usr/bin/env ruby -wKU

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'net/http'
require "selenium-webdriver"

IPHONE_USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X; en-us) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53'

class Domium

  def initialize(sites=[])
    
  end

  def make_5000_best_page_url(page_number)
    "http://5000best.com/?w.c&xml=1&ta=32&p=#{page_number}&sortby=0&ise=&h=03"
  end

  def parse_best_page(page_number)
    page_url = self.make_5000_best_page_url page_number

    page = Nokogiri::HTML(open(page_url))

    table_links = page.xpath(".//table[@id='ttable']//tr")

    sites = []
    table_links.each do |link|
      category = link.xpath("./td/a[contains(@href, '/websites/')]")[0].text
      url      = link.xpath("./td/a[@rel='nofollow']")[0]['href']
      rank     = link.xpath("./td[1]")[0].text
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
    path   = url.path
    path ||= "/"
    req = Net::HTTP::Get.new(path, {'User-Agent' => IPHONE_USER_AGENT})
    response = Net::HTTP.start( url.host, url.port ) { |http| http.request( req ) }
    page = Nokogiri::HTML(response.body)

    redirects = false
    redirects = self.has_serverside_mobile_redirect? response
    unless redirects
      cs_redirects = self.has_clientside_modile_redirect? url
    end

    mobile_redirect = (redirects || cs_redirects)

    responsive = false

    unless mobile_redirect
      responsive = self.is_responsive? response, url_query, page
    end

    # puts "\n URL: #{url_query}\n mobile_redirect: #{(redirects || cs_redirects)}\n responsive: #{responsive}"
    return {mobile_redirect: mobile_redirect, responsive: responsive}
  end

  def has_ad?(url_query)
    url    = URI.parse(url_query)
    path   = url.path
    path ||= "/"
    req = Net::HTTP::Get.new(path, {'User-Agent' => IPHONE_USER_AGENT})
    response = Net::HTTP.start( url.host, url.port ) { |http| http.request( req ) }
    page = Nokogiri::HTML(response.body)
    adwords = page.xpath("//script[not(@src)]")
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
    driver = Selenium::WebDriver.for :chrome, switches: %W[--user-agent=#{IPHONE_USER_AGENT}]
    driver.manage.window.resize_to(320, 536)
    driver.navigate.to url
    page_url = driver.execute_script("return window.location.host + window.location.path")
    driver.quit
    return is_mobile_url? page_url
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
        
        req = Net::HTTP::Get.new(url.path)
        response = Net::HTTP.start( url.host, url.port ) { |http| http.request( req ) }
        responsive = response.body.include? '@media' if response.body.include? '@media'  
        return true if responsive
      end
    end
    return responsive
  end

end