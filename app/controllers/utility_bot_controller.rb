require 'net/https'
require 'json'
require 'uri'

class UtilityBotController < ActionController::Base
	@@supported_news_providers = { 
		"ABS-CBN News": "ABS", 
		"Rappler": "Rappler", 
		#"INQUIRER.net": "Inquirer", 
		#"GMA News": "GMA"
		#"CNN Philippines": "CNN"
	}

	def index
		render json: "{ 'message': 'Hello from UtilityBot index' }"
	end

	def determine
		feature = params[:feature]
		subfeature = params[:subfeature]
		search = params[:search]
		data = []

		if feature == "scrape"
			if subfeature == "news"
				url = "https://news.google.com/?hl=en-PH&gl=PH&ceid=PH:en"
				if search
					url = "https://news.google.com/search?q=" + search + "&hl=en-PH&gl=PH&ceid=PH:en"
					resp_escaped = scrape url
					main = /<main.*?>(.*?)<\/main>/.match( resp_escaped ).to_s
					articles = main.scan( /<article.*?jslog=\".*?:(.*?);.*?<h3.*?a href=\"\..*?\".*?>(.*?)<\/a>.*?<a.*?class=\".*?\">(.*?)<\/a>/ )					
					#filter_for_articles = Regexp.new( "<article.*?jslog=\".*?:(.*?);.*?<h3.*?a href=\"\..*?\".*?>(.*?)<\/a>.*?<a.*?class=\".*?\">(.*?)<\/a>" )
					#articles = article_areas.scan( filter_for_articles )
					for x in articles do
						if @@supported_news_providers.keys.include? :"#{x[2]}"
							x = x.map{ |a| sanitize(a) }
							data << x
						end
					end
					render json: "{ \"message\": #{data} }"
				else
					#url = "https://www.facebook.com"
					resp_escaped = scrape url
					main = /<main.*?>(.*?)<\/main>/.match( resp_escaped ).to_s
					#article_areas = main.scan( /<div jscontroller=\".*?\" jsmodel=\".*?\" jsaction=\".*?\" data-n-ham=\".*?\" data-n-cvid=\".*?\" jsdata=\".*?\" jslog=\".*?\" class=\".*?\">.*?<\/h3><div.*?<div.*?<div.*?<a class=\".*?\">.*?<\/a>/ ).join( "" )
					#filter_for_articles = Regexp.new( "<article.*?jslog=\".*?:(.*?);.*?<h3.*?a href=\"\..*?\".*?>(.*?)<\/a>.*?<a.*?class=\"wEwyrc AVN2gc uQIVzc Sksgp\">(.*?)<\/a>" )
					articles = main.scan( /<div class=\"xrnccd F6Welf R7GTQ keNKEd j7vNaf\">.*?<article.*?jslog=\".*?;.*?:(.*?);.*?<h3.*?class=\"ipQwMb ekueJc RD0gLb\".*?>.*?<a.*?>(.*?)<\/a>.*?<div class="QmrVtf RD0gLb">.*?<a.*?>(.*?)<\/a>/ )
					for x in articles do
						if @@supported_news_providers.keys.include? :"#{x[2]}"
							x = x.map{ |a| sanitize(a) }
							data << x
						end
					end
					render json: "{ \"message\": #{data} }"
				end
			elsif subfeature == "main_news_crawl"
				init_main_news_crawl
			end
		end
	end

	def scrape( url )
		url_to_scrape = URI( url )
		resp_from_url = Net::HTTP.get_response(url_to_scrape)
		resp_body = resp_from_url.body.force_encoding('UTF-8')
		resp_escaped = remove_newlines( resp_body )
		return resp_escaped
	end

	def sanitize( text )
		text = text.gsub( /<.*?>|&.*?;|\&lt;.*?\&gt;/, '' )
		return text
	end

	def init_main_news_crawl
		link = sanitize( params[:link] )
		title = sanitize( params[:title] )
		newsp = sanitize( params[:newsp] )
		news_info = [ params[:link], params[:title], params[:newsp] ]
		eval "crawl_" + @@supported_news_providers[:"#{news_info[2]}"] + "( news_info )"
	end

	def crawl_ABS( news_info )
		resp_escaped = scrape news_info[0]
		article = /<article class=\"article\-block animated\-content sticker\">(.*?)<\/article>/.match( resp_escaped ).to_s
		title = article.scan( /<h1 class=\"news\-title\">(.*?)<\/h1>/ )[0]
		body = article.scan( /<!-- SHARE CONTENT -->(.*?)<!-- SHARE CONTENT -->/ ).to_s
		body_parsed = sanitize( body.scan( /<p>(.*?)<\/p>/ )[1..].join( "" ) )
		title = JSON.generate( title )
		body_parsed = JSON.generate( body_parsed )
		render json: "{ \"title\": #{title}, \"body\": #{body_parsed} }"
	end

	def crawl_Rappler( news_info )
		resp_escaped = scrape news_info[0]
		article = /<div id=\"story\-area\-.*?\".*?>.*?<h1.*?>(.*?)<\/h1>.*?<div class=\"cXenseParse\">(.*?)<div.*?\/div>(.*?)<\/div>/.match( resp_escaped ).to_s
		title = article.scan( /<h1.*?>(.*?)<\/h1>/ )[0][0]
		body = article.scan( /<p>(.*?)<\/p>/ ).join( "" )
		body_parsed = sanitize( body )
		title = JSON.generate( title )
		body_parsed = JSON.generate( body_parsed )
		render json: "{ \"title\": #{title}, \"body\": #{body_parsed} }"
	end

	def crawl_Inquirer( news_info )
		resp_escaped = scrape news_info[0]
		article = /<article id="single_lb">.*?<\/article>/.match( resp_escaped ).to_s
		if article.length < 1
			article = /<article id=\"article_level_wrap\" data\-io\-article\-url=\".*?\">.*?<\/article>/.match( resp_escaped ).to_s
			title = article.scan( /<h1.*?>(.*?)<\/h1>/ )[0][0]
			body = article.scan( /^<p>[[:alpha:]](.*?)<\/p>/ ).join( "" )
			body_parsed = sanitize( body )
		else

		end
		json = JSON.generate( "{ \"title\": \"#{title}\", \"body\": \"#{body_parsed}\" }" )
		render json: json
	end

	def crawl_CNN( news_info )
		resp_escaped = scrape news_info[0]
		article = /<article role=\"main\".*?>.*?<h1 class=\"title\">.*?<\/article>.*?<\/article>/.match( resp_escaped ).to_s
		#title = article.scan( /<h1 class=\"title\">(.*?)<\/h1>/ )[0][0]
		body = /<div id=\"content\-body.*?\">(.*?)<\/article>/.match( article ).to_s
		body_parsed = sanitize( body.scan( /<p>(?!\&)(.*?)<\/p>/ ).join( "" ) )
		title = JSON.generate( title )
		body_parsed = JSON.generate( body_parsed )
		#render json: "{ \"title\": #{title}, \"body\": #{body_parsed} }"
		render json: "{ \"article\": #{resp_escaped} }"
	end

	def remove_newlines( str )
		str = str.gsub( /\n|\n$|^\n| {2,}|^\t{1,}|\t{1,}$|\t{1,}|\s{2,}/, '' )
		return str
	end
end