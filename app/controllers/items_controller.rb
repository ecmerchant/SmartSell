class ItemsController < ApplicationController

  require 'nokogiri'
  require 'open-uri'
  require 'peddler'
  require 'amazon/ecs'
  require 'uri'

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

      if i == 10 then
        logger.debug(i)
        logger.debug("key=" + key)

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
          image = item.get('MediumImage/URL')
          if image == nil then
            image = item.get('ImageSets/ImageSet/MediumImage/URL')
          end

          if lowprice == nil then
            lowprice = 0
          end
          mpn = item.get('ItemAttributes/MPN')
          if image != nil then
            data[k][2] = '<img src="' + image + '" width="80" height="60">'
          else
            data[k][2] = ""
          end
          data[k][3] = title
          data[k][5] = lowprice
          data[k][6] = mpn
          data[k][7] = "⇒"
          k += 1
        end

        for tas in asin

          temp = doc.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
          temp = temp.xpath(".//LandedPrice/Amount")[0]
          if temp != nil then
            lowest = temp.text
          else
            lowest = 0
          end
          data[j][4] = String(lowest.to_i)
          j += 1
        end

        asin = []
        key = ""
        i = 0
      end
    end

    if i > 0  then
      logger.debug("key=" + key)
      parser = client.get_lowest_offer_listings_for_asin(asin,{item_condition: 'Used'})
      doc = Nokogiri::XML(parser.body)
      doc.remove_namespaces!

      for tas in asin
        temp = doc.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
        temp = temp.xpath(".//LandedPrice/Amount")[0]
        if temp != nil then
          lowest = temp.text
        else
          lowest = 0
        end
        data[j][4] = String(lowest.to_i)
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
        image = item.get('MediumImage/URL')
        if image == nil then
          image = item.get('ImageSets/ImageSet/MediumImage/URL')
        end
        lowprice = item.get('OfferSummary/LowestNewPrice/Amount')

        if lowprice == nil then
          lowprice = 0
        end
        mpn = item.get('ItemAttributes/MPN')
        if image != nil then
          data[k][2] = '<img src="' + image + '" width="80" height="60">'
        else
          data[k][2] = ""
        end
        data[k][3] = title
        data[k][5] = lowprice
        data[k][6] = mpn
        data[k][7] = "⇒"
        k += 1
      end

    end

    render json: data
  end

  def connect
    body = params[:data]
    title = body[:title]
    mpn = body[:mpn]

    logger.debug(body)

    cuser = current_user.email
    account = Rule.find_by(user:cuser)

    keyword = mpn

    enc_keyword = URI.escape(keyword)

    if account != nil then
      surl = account.url
      surl = surl.gsub("query",enc_keyword)
      eurl = surl.gsub("search/search?","closedsearch/closedsearch?")
    else

    end

    #終了したオークションへのアクセス
    charset = nil
    html = open(eurl) do |f|
      charset = f.charset # 文字種別を取得
      f.read # htmlを読み込んで変数htmlに渡す
    end
    doc = Nokogiri::HTML.parse(html, nil, charset)

    temp = doc.xpath('//span[@class="ePrice"]')

    ePrices = []
    i = 0
    temp.each do |elem|
      ePrices[i] = CCur(elem.inner_text)
      i += 1
    end


    #落札平均価格、最高価格、最低価格（過去50件分）
    if ePrices[0] != nil then
      avgPrice = ePrices.inject(0.0){|r,i| r+=i }/ePrices.size
      maxPrice = ePrices.max
      minPrice = ePrices.min
    else
      avgPrice = 0
      maxPrice = 0
      minPrice = 0
    end

    #開催中オークションへのアクセス
    charset = nil
    html = open(surl) do |f|
      charset = f.charset # 文字種別を取得
      f.read # htmlを読み込んで変数htmlに渡す
    end
    doc = Nokogiri::HTML.parse(html, nil, charset)


    temp = doc.xpath('//td[@class="i"]')[0]

    if temp != nil then
      furl = temp.css('a')[0][:href]
      title = doc.xpath('//h3')[0].inner_text
      image = temp.css('img')[0][:src]
      image = '<img src="' + image + '" width="80" height="60">'
      cPrice = doc.xpath('//td[@class="pr1"]/text()')[0]
      bPrice = doc.xpath('//td[@class="pr2"]/text()')[0]
      if cPrice != nil then
        cPrice = cPrice.inner_text
        cPrice = CCur(cPrice)
      else
        cPrice = 0
      end

      if bPrice != nil then
        bPrice = bPrice.inner_text
        bPrice = CCur(bPrice)
      else
        bPrice = 0
      end

    else
      furl = ""
      title = "該当なし"
      image = ""
      cPrice = 0
      bPrice = 0
    end

    if surl != nil && surl != "" then
      surl = '<a href="' + surl + '" target="_blank">' + surl + '</a>'
    end

    if furl != nil && furl != "" then
      furl = '<a href="' + furl + '" target="_blank">' + furl + '</a>'
    end

    result = [
      surl,
      maxPrice,
      furl,
      image,
      title,
      cPrice,
      bPrice,
      keyword
    ];

    render json:result
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

  private def CCur(value)
    res = value.gsub(/\,/,"")
    res = res.gsub(/円/,"")
    res = res.gsub(/ /,"")
    res = res.to_i
    return res
  end

end
