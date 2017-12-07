class ItemsController < ApplicationController

  require 'nokogiri'
  require 'open-uri'
  require 'peddler'
  require 'amazon/ecs'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def show
      @user = current_user.email
  end

  def regist
    current_email = current_user.email
    @user = current_email
    if request.post? then
      @account = Mws.new
      data = params[:MWS]
      logger.debug("\n\nDebug")
      logger.debug(data)
      user = Mws.find_by(User: current_email)
      if data[:AWSkey] != nil && data[:Skey] != nil && data[:SellerId] != nil then
        if user == nil then
          Mws.create(
            User: current_user.email,
            AWSkey: data[:AWSkey],
            Skey: data[:Skey],
            SellerId:data[:SellerId]
          )
        else
          user.AWSkey = data[:AWSkey]
          user.Skey = data[:Skey]
          user.SellerId = data[:SellerId]
          user.save
          @res1 = data[:AWSkey]
          @res2 = data[:Skey]
          @res3 = data[:SellerId]
        end
      end
    else
      temp = Mws.find_by(User:current_email)
      logger.debug("MWS is search!!\n\n")
      logger.debug(Mws.select("AWSkey"))
      if temp != nil then
        logger.debug("MWS is found")
        @account = Mws.find_by(user:current_email)
        @res1 = temp.AWSkey
        @res2 = temp.Skey
        @res3 = temp.SellerId
      else
        @account = Mws.new
      end
    end
  end

  def search

    body = params[:data]
    body = JSON.parse(body)
    org_url = body[0]
    pgnum = body[1]
    maxnum = body[2]
    cnum = body[3]

    user = current_user.email

    j = 0
    data = []
    charset = nil

    url = org_url + '&page=' + pgnum.to_s
    user_agent = "Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0"

    begin
      html = open(url, "User-Agent" => user_agent) do |f|
        charset = f.charset
        f.read # htmlを読み込んで変数htmlに渡す
      end
    rescue OpenURI::HTTPError => error
      response = error.io
      logger.debug("\nNo." + pgnum.to_s + "\n")
      logger.debug("error!!\n")
      logger.debug(error)
    end

    doc = Nokogiri::HTML.parse(html, charset)
    doc.css('li/@data-asin').each do |list|
      cnum += 1
      logger.debug(cnum)
      logger.debug(list.value)
      if cnum > maxnum then
        break;
      end
      check = "a-popover-sponsored-header-" + list.value
      if doc.xpath('//div[@id=' + check + ']')[0] == nil then
        data[j] = []
        for x in 0..13
          data[j][x] = ""
        end
        data[j][0] = ""
        data[j][1] = list.value
        data[j][6] = "⇒"
        j += 1
      end
    end


    #Amazonデータの取得
    account = Mws.find_by(User:user)
    if account == nil then

    end

    saws = account.AWSkey
    skey = account.Skey
    sid = account.SellerId

    client = MWS.products(
      primary_marketplace_id: "A1VC38T7YXB528",
      merchant_id: sid,
      aws_access_key_id: saws,
      aws_secret_access_key: skey
    )

    aaws = "AKIAJWYZXQ57QND7DNEA"
    akey = "iNDLIrTVK84d/qxVHAWfra97nfV9eOMLaYOBMexf"
    aid = "mamegomari-22"

    Amazon::Ecs.configure do |options|
      options[:AWS_access_key_id] = aaws
      options[:AWS_secret_key] = akey
      options[:associate_tag] = aid
    end

    asin = []
    i = 0
    j = 0
    k = 0

    key = ""
    for ta in data
      asin[i] = ta[1]
      key = key + ta[1] + ","

      i += 1
      logger.debug(i)
      logger.debug("\n")
      if i == 10 then
        logger.debug(i)

        parser = client.get_lowest_offer_listings_for_asin(asin,{item_condition: 'Used'})
        doc = Nokogiri::XML(parser.body)
        doc.remove_namespaces!

        key = key.slice(0,key.length-1)

        try = 0
        times = 5
        begin
          aws = Amazon::Ecs.item_lookup(key, {:response_group => 'Large,OfferFull',:country => 'jp'})
          try += 1
        rescue
          sleep(1)
          retry if try < times
        end

        tch = aws.items.each do |item|
          title = ""
          lowprice = 0
          mpn = ""
          title = item.get('ItemAttributes/Title')
          lowprice = item.get('OfferSummary/LowestNewPrice/Amount')
          mpn = item.get('ItemAttributes/MPN')

          data[k][2] = title
          data[k][4] = lowprice
          data[k][5] = mpn
          k += 1
        end

        for tas in asin

          temp = doc.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
          temp = temp.xpath(".//LandedPrice/Amount")[0]
          if temp != nil then
            lowest = temp.text
          else
            lowest = "-"
          end
          data[j][3] = String(lowest.to_i)
          j += 1
        end

        asin = []
        key = ""
        i = 0
      end
    end

    if i > 0 then

      parser = client.get_lowest_offer_listings_for_asin(asin,{item_condition: 'Used'})
      doc = Nokogiri::XML(parser.body)
      doc.remove_namespaces!

      for tas in asin
        temp = doc.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
        temp = temp.xpath(".//LandedPrice/Amount")[0]
        if temp != nil then
          lowest = temp.text
        else
          lowest = "-"
        end
        data[j][3] = String(lowest.to_i)
        j += 1
      end

      try = 0
      times = 5
      begin
        aws = Amazon::Ecs.item_lookup(key, {:response_group => 'Large,OfferFull',:country => 'jp'})
        try += 1
      rescue
        sleep(1)
        retry if try < times
      end

      tch = aws.items.each do |item|
        title = ""
        lowprice = 0
        mpn = ""
        title = item.get('ItemAttributes/Title')
        lowprice = item.get('OfferSummary/LowestNewPrice/Amount')
        mpn = item.get('ItemAttributes/MPN')

        data[k][2] = title
        data[k][4] = lowprice
        data[k][5] = mpn
        k += 1
      end

    end

    render json: data
  end

  def connect
    body = params[:data]
    title = body[:title]
    mpn = body[:mpn]

    cuser = current_user.email
    account = Rule.find_by(user:cuser)

    if account != nil then
      surl = account.url
      surl = surl.gsub("query",mpn)
      eurl = surl.gsub("search/search?","closedsearch/closedsearch?")
    else

    end

    logger.debug(surl)




    charset = nil
    html = open(surl) do |f|
      charset = f.charset # 文字種別を取得
      f.read # htmlを読み込んで変数htmlに渡す
    end
    doc = Nokogiri::HTML.parse(html, nil, charset)

    res = {
      url: surl,

    }

    render json:body
  end

  def setup

    cuser = current_user.email
    surl = URI("https://auctions.yahoo.co.jp/search/search?")
    surl.query = params.to_param


    account = Rule.find_by(user:cuser)

    if account != nil then
      account.update(
        url: surl
      )
    else
      Rule.create(
        user: cuser,
        url: surl
      )
    end

    logger.debug(surl.to_s)

  end

end
