#!/usr/bin/env ruby -wKU
require_relative "../bin/domium.rb"
require "minitest/autorun"

describe Domium do
  before do 
    @domium = Domium.new
  end

  describe "when asking for a 5000 best page url" do
    it "must return a valid URL" do
      page_number = Random.rand(100)
      @domium.make_5000_best_page_url(page_number).must_equal("http://5000best.com/?w.c&xml=1&ta=32&p=#{page_number}&sortby=0&ise=&h=03")
    end
    it "must have a first site" do
      sites = @domium.parse_best_page(1)
      # puts sites
      sites[0][:rank].must_equal("1.")
    end

    it "must have a category" do
      sites = @domium.parse_best_page(1)

      sites[0][:category].wont_equal nil 
    end

    it "must have a url" do
      sites = @domium.parse_best_page(1)

      sites[0][:url].must_match /^((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+(:[0-9]+)?|(?:ww‌​w.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%\@.\w_]*)#?‌​(?:[\w]*))?)/i

    end
  end

  describe "when checking if it is a mobile site" do
    it "must return true, if the site for serverside redirects for mobile" do
      @domium.is_mobile?("http://www.charlotterusse.com/")[:mobile_redirect].must_equal true
    end
    it "must return true if the site has clientside redirects" do
      @domium.is_mobile?("http://www.adorama.com/")[:mobile_redirect].must_equal true
    end
    it "must return true if the site is responsive" do
      @domium.is_mobile?("http://www.bostonglobe.com/")[:responsive].must_equal true
    end
  end

  describe "when checking for ads" do
    it "must tell me if there is a google ad!" do
      @domium.has_ad?("http://www.thisnext.com/item/0D53228B/D34EB201/Glossi-by-Fashion-Bloggers")[:has_google_ad].must_equal true
    end
  end

  # comment out because slow and there's no good way to skip in minitest.
  # it "should return 50 pages by default" do
  #   all_pages = @domium.parse_best_pages

  #   all_pages.length.must_equal(5000)
  # end

  # it "should allow you to limit pages" do
  #   all_pages = @domium.parse_best_pages(10..20)

  #   all_pages.length.must_equal(1100)
  # end

  # describe "when asking for sites" do
  #   it "must grab sites from the alexa top 1000"

  #   end
  # end
end 