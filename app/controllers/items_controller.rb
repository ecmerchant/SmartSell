class ItemsController < ApplicationController

  require 'nokogiri'
  require 'open-uri'
  require 'peddler'
  require 'amazon/ecs'
  require 'uri'
  require 'csv'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def show
    @user = current_user.email
    csv_data = CSV.read('app/others/csv/Flat.File.Listingloader.jp.csv', headers: true)
    gon.csv_head = csv_data
    account = Fvalue.find_by(user: current_user.email)
    if account != nil then
      res = account.list
      gon.list = account.list
    else
      gon.list = false
    end

    rt = Asin.where(user:current_user.email).pluck("rasin")
    nrt = []
    k = 0
    for p in 0..rt.length
      if rt[p] != nil then
        nrt[k]=[]
        nrt[k][0] = rt[p]
        k += 1
      end
    end

    qt = Asin.where(user:current_user.email).pluck("nasin")
    nqt = []
    k = 0
    for p in 0..qt.length
      if qt[p] != nil then
        nqt[k]=[]
        nqt[k][0] = qt[p]
        k += 1
      end
    end

    gon.regasin = nrt
    gon.ngasin = nqt

  end


  def regist
    current_email = current_user.email
    @user = current_email
    if request.post? then
      @account = Mws.new
      data = params[:MWS]
      logger.debug("\n\nDebug")
      user = Mws.find_by(User: current_email)
      if data[:AWSkey] != nil && data[:SellerId] != nil then
        if user == nil then
          Mws.create(
            User: current_user.email,
            AWSkey: data[:AWSkey],
            Skey: data[:Skey],
            SellerId:data[:SellerId]
          )
          @res1 = data[:AWSkey]
          @res2 = data[:Skey]
          @res3 = data[:SellerId]
        else
          Mws.update(
            User: current_user.email,
            AWSkey: data[:AWSkey],
            Skey: data[:Skey],
            SellerId: data[:SellerId]
          )
          @res1 = data[:AWSkey]
          @res2 = data[:Skey]
          @res3 = data[:SellerId]
        end
      else
        @res1 = data[:AWSkey]
        @res2 = data[:Skey]
        @res3 = data[:SellerId]
      end
    else
      temp = Mws.find_by(User:current_email)
      logger.debug("MWS is search!!\n\n")
      logger.debug(Mws.select("AWSkey"))
      if temp != nil then
        logger.debug("MWS is found")
        @account = Mws.find_by(User:current_email)
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
    input_type = body[4].to_i
    reg_asin = body[5]
    ng_asin = body[6]
    logger.debug(reg_asin)
    user = current_user.email

    if User.find_by(user: user).access_flg != true then
      maxnum = 20
    end

    if input_type == 1 then
      logger.debug("Case URL")
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
          break
        end
        check = "a-popover-sponsored-header-" + list.value
        if doc.xpath('//div[@id=' + check + ']')[0] == nil then
          if ng_asin.flatten.include?(list.value) == false then
            data[j] = []
            for x in 0..28
              data[j][x] = ""
            end
            data[j][0] = false
            data[j][1] = false
            data[j][9] = list.value
            data[j][14] = "⇒"
            j += 1
          end
        end
      end
    else
      j = 0
      data = []
      for j in 0..reg_asin.length - 1
        if reg_asin[j][0] == nil then
          break
        end
        data[j] = []
        for x in 0..28
          data[j][x] = ""
        end
        data[j][0] = false
        data[j][1] = false
        data[j][9] = reg_asin[j][0]
        data[j][14] = "⇒"
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
    id_type = 'ASIN'
    asin = []
    asin_s = []
    requests = []
    i = 0
    j = 0
    k = 0
    m = 0
    counter = 0

    for ta in data
      asin[i] = ta[9]
      asin_s[j] = ta[9]

      prices = {
        ListingPrice: { Amount: 1000, CurrencyCode: "JPY", }
      }

      request = {
        MarketplaceId: "A1VC38T7YXB528",
        IdType: "ASIN",
        IdValue: asin[i],
        PriceToEstimateFees: prices,
        Identifier: "req" + i.to_s,
        IsAmazonFulfilled: false
      }

      requests[i] = request

      i += 1
      j += 1
      counter += 1

      if j == 5 || counter == data.length then
        logger.debug(asin_s)
        parser3 = client.get_matching_product_for_id(id_type, asin_s)
        doc3 = Nokogiri::XML(parser3.body)
        doc3.remove_namespaces!

        for tas in asin_s
          temp = doc3.xpath("//GetMatchingProductForIdResult[@Id='" + tas + "']")[0]
          title = temp.xpath('.//ItemAttributes/Title')
          if title != nil then
            title = title.text
            logger.debug(title)
          end

          image = temp.xpath('.//SmallImage/URL')
          if image != nil then
            image = image.text
            image = image.gsub('SL75','SL150')
          end

          mpn =  temp.xpath('.//ItemAttributes/PartNumber')
          if mpn != nil then
            mpn = mpn.text
          end

          if image != nil then
            data[k][2] = '<img src="' + image + '" width="80" height="60">'
          else
            data[k][2] = ""
          end
          data[k][7] = '<a href="https://amazon.co.jp/dp/' + data[k][9] + '" target="_blank">' + 'https://amazon.co.jp/dp/' + data[k][7] + '</a>'
          data[k][8] = title
          data[k][12] = mpn
          k += 1
        end
        asin_s = []
        j = 0
      end

      if i == 10 || counter == data.length then

        parser = client.get_lowest_offer_listings_for_asin(asin,{item_condition: 'Used'})
        parser1 = client.get_lowest_offer_listings_for_asin(asin,{item_condition: 'New'})
        parser2 = client.get_my_fees_estimate(requests)

        doc = Nokogiri::XML(parser.body)
        doc.remove_namespaces!

        doc1 = Nokogiri::XML(parser1.body)
        doc1.remove_namespaces!

        doc2 = Nokogiri::XML(parser2.body)
        doc2.remove_namespaces!

        for tas in asin

          temp = doc.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
          temp = temp.xpath(".//LandedPrice/Amount")[0]

          temp1 = doc1.xpath("//GetLowestOfferListingsForASINResult[@ASIN='" + tas + "']")[0]
          temp1 = temp1.xpath(".//LandedPrice/Amount")[0]

          fee = 0
          temp2 = doc2.xpath("//FeesEstimateResult")
          for tt in temp2
            casin = tt.xpath("FeesEstimateIdentifier/IdValue")[0].text
            if casin == tas then
              tfee = tt.xpath("FeesEstimate/FeeDetailList/FeeDetail/FeeAmount/Amount")[0]
              if tfee != nil then
                fee = tfee.text
                break
              end
            end
          end

          if temp != nil then
            lowest = temp.text
          else
            lowest = 0
          end

          if temp1 != nil then
            lowprice = temp1.text
          else
            lowprice = 0
          end

          data[m][10] = String(lowest.to_i)
          data[m][11] = String(lowprice.to_i)
          data[m][13] = String(fee.to_i/10)
          m += 1
        end

        asin = []
        i = 0
      end
    end

    render json: data
  end


  def upload
    logger.debug("\n\n\n")
    logger.debug("Debug Start!")
    current_email = current_user.email

    user= Mws.find_by(user:current_email)
    aws = user.AWSkey
    skey = user.Skey
    seller = user.SellerId

    res = params[:data]

    client = MWS.feeds(
      primary_marketplace_id: "A1VC38T7YXB528",
      merchant_id: seller,
      aws_access_key_id: aws,
      aws_secret_access_key: skey
    )

    res1 = JSON.parse(res)

    logger.debug("Pre Feed Content is \n\n")

    kk = 0
    feed_body = ""
    while kk < res1.length
      feed_body = feed_body + res1[kk].join("\t")
      feed_body = feed_body + "\n"
      kk += 1
    end

    mappings = {
      "\u{00A2}" => "\u{FFE0}",
      "\u{00A3}" => "\u{FFE1}",
      "\u{00AC}" => "\u{FFE2}",
      "\u{2016}" => "\u{2225}",
      "\u{2012}" => "\u{FF0D}",
      "\u{301C}" => "\u{FF5E}"
    }

    mappings.each{|before, after| feed_body = feed_body.gsub(before, after) }
    new_body = feed_body.encode(Encoding::Windows_31J, undef: :replace)

    logger.debug("Feed Content is \n\n")
    logger.debug(new_body)

    feed_type = "_POST_FLAT_FILE_LISTINGS_DATA_"
    parser = client.submit_feed(new_body, feed_type)
    doc = Nokogiri::XML(parser.body)

    submissionId = doc.xpath(".//mws:FeedSubmissionId", {"mws"=>"http://mws.amazonaws.com/doc/2009-01-01/"}).text
=begin
    process = ""
    err = 0
    while process != "_DONE_" do
      sleep(25)
      list = {feed_submission_id_list: submissionId}
      parser = client.get_feed_submission_list(list)
      doc = Nokogiri::XML(parser.body)
      process = doc.xpath(".//mws:FeedProcessingStatus", {"mws"=>"http://mws.amazonaws.com/doc/2009-01-01/"}).text
      logger.debug(doc)
      err += 1
      if err > 1 then
        break
      end
    end


    parser = client.get_feed_submission_result(submissionId)
    doc = Nokogiri::XML(parser.body)
    logger.debug(doc)
    logger.debug("\n\n")
    #submissionId = doc.match(/FeedSubmissionId>([\s\S]*?)<\/Feed/)[1]
    #parser.parse # will return a Hash object
=end
    res = ["test"]
    render json: res
  end


  def reload
    body = params[:data]
    furl = body[:url]

    if furl != nil && furl != "" then

      ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
      uanum = ua.length
      user_agent = ua[rand(uanum)][0]
      logger.debug("\n\nagent is ")
      logger.debug(user_agent)
      logger.debug(furl)
      charset = nil
      begin
        html = open(furl, "User-Agent" => user_agent) do |f|
          charset = f.charset
          f.read # htmlを読み込んで変数htmlに渡す
        end
      rescue OpenURI::HTTPError => error
        response = error.io
        logger.debug("error!!\n")
        logger.debug(error)
      end

      doc = Nokogiri::HTML.parse(html, nil, charset)

      title = doc.xpath('//h1[@class="ProductTitle__text"]')[0].inner_text
      aucid = furl[furl.index("auction/")+8..-1]

      tc = doc.xpath('//div[@class="Price Price--current"]')[0]
      if tc != nil then
        cPrice = tc.xpath('//dd[@class="Price__value"]/text()')[0]
        cPrice = CCur(cPrice.inner_text)
      else
        cPrice = 0
      end

      tb = doc.xpath('//div[@class="Price Price--buynow"]')[0]
      if tb != nil then
        bPrice = tb.xpath('//dd[@class="Price__value"]/text()')[0]
        bPrice = CCur(bPrice.inner_text)
      else
        bPrice = 0
      end

      temp = doc.xpath('//ul[@class="ProductImage__images"]')[0]
      images = temp.css('img')
      b = 0
      imgs = []
      for img in images
        imgs[b] = img[:src]
        b += 1
      end

      image = '<img src="' + imgs[0] + '" width="80" height="60">'

      furl = '<a href="' + furl + '" target="_blank">' + furl + '</a>'
      seller = doc.xpath('//span[@class="Seller__name"]/a')[0].inner_text
      pfb = doc.xpath('//span[@class="Seller__ratingGood"]')[0].inner_text
      nfb = doc.xpath('//span[@class="Seller__ratingBad"]')[0].inner_text
    end

    #利益などの計算

    result = [
      image,
      furl,
      title,
      aucid,
      cPrice,
      bPrice,
      seller,
      pfb,
      nfb
    ];

    maxnumber = 5
    if furl != nil && furl != "" then
      for p in 0..maxnumber
        if p > imgs.length then
          result.push("")
        else
          result.push(imgs[p])
        end
      end
    else
      for p in 0..maxnumber
        result.push("")
      end
    end
    render json:result
  end

  def connect
    body = params[:data]
    title = body[:title]
    mpn = body[:mpn]
    qtype = body[:qtype]

    cuser = current_user.email
    account = Rule.find_by(user:cuser)
    logger.debug("query target is ")
    logger.debug(qtype)
    if qtype == "1" then
      keyword = mpn
    else
      keyword = title
    end
    enc_keyword = URI.escape(keyword)

    if account != nil then
      surl = account.url
      surl = surl.gsub("query",enc_keyword)
      eurl = surl.gsub("search/search?","closedsearch/closedsearch?")
    else
      surl = "https://auctions.yahoo.co.jp/search/search?va=&vo=&ve=&ngrm=0&fixed=0&auccat=0&aucminprice=&aucmaxprice=&aucmin_bidorbuy_price=&aucmax_bidorbuy_price=&l0=0&abatch=0&istatus=0&gift_icon=0&charity=&ei=UTF-8&tab_ex=commerce&catid=0&slider=0&f_adv=1&fr=auc_adv&f=0x2"
      surl = surl.gsub("query",enc_keyword)
      eurl = surl.gsub("search/search?","closedsearch/closedsearch?")
    end

    #終了したオークションへのアクセス
    charset = nil
    ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
    uanum = ua.length
    user_agent = ua[rand(uanum)][0]
    logger.debug("\n\nagent is ")
    logger.debug(user_agent)
    begin
      html = open(eurl, "User-Agent" => user_agent) do |f|
        charset = f.charset
        f.read # htmlを読み込んで変数htmlに渡す
      end
    rescue OpenURI::HTTPError => error
      response = error.io
      logger.debug("error!!\n")
      logger.debug(error)
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
      avgPrice = avgPrice.round(0)
      maxPrice = ePrices.max
      minPrice = ePrices.min
    else
      avgPrice = 0
      maxPrice = 0
      minPrice = 0
    end

    #開催中オークションへのアクセス
    charset = nil
    ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
    uanum = ua.length
    user_agent = ua[rand(uanum)][0]
    logger.debug("\n\nagent is ")
    logger.debug(user_agent)
    begin
      html = open(surl, "User-Agent" => user_agent) do |f|
        charset = f.charset
        f.read # htmlを読み込んで変数htmlに渡す
      end
    rescue OpenURI::HTTPError => error
      response = error.io
      logger.debug("error!!\n")
      logger.debug(error)
    end
    doc = Nokogiri::HTML.parse(html, nil, charset)


    temp = doc.xpath('//td[@class="i"]')[0]

    if temp != nil then
      furl = temp.css('a')[0][:href]
      title = doc.xpath('//h3')[0].inner_text
      image = temp.css('img')[0][:src]
      image = '<img src="' + image + '" width="80" height="60">'
      cPrice = doc.xpath('//td[@class="pr1"]')[0].inner_html
      bPrice = doc.xpath('//td[@class="pr2"]')[0].inner_html

      if cPrice.index("span") == nil then
        cPrice = doc.xpath('//td[@class="pr1"]/text()')[0]
      else
        cPrice = doc.xpath('//td[@class="pr1"]/span/text()')[0]
      end

      logger.debug(bPrice)
      if bPrice.index("span") == nil then
        bPrice = doc.xpath('//td[@class="pr2"]/text()')[0]
      else
        bPrice = doc.xpath('//td[@class="pr2"]/span/text()')[0]
      end
      logger.debug(cPrice)

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
      aucid = ""
    else
      furl = ""
      title = "該当なし"
      image = ""
      cPrice = 0
      bPrice = 0
      aucid = ""
    end

    if surl != nil && surl != "" then
      surl = '<a href="' + surl + '" target="_blank">' + surl + '</a>'
    end

    if furl != nil && furl != "" then

      charset = nil
      ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
      uanum = ua.length
      user_agent = ua[rand(uanum)][0]
      logger.debug("\n\nagent is ")
      logger.debug(user_agent)
      begin
        html = open(furl, "User-Agent" => user_agent) do |f|
          charset = f.charset
          f.read # htmlを読み込んで変数htmlに渡す
        end
      rescue OpenURI::HTTPError => error
        response = error.io
        logger.debug("error!!\n")
        logger.debug(error)
      end

      doc = Nokogiri::HTML.parse(html, nil, charset)

      temp = doc.xpath('//ul[@class="ProductImage__images"]')[0]
      images = temp.css('img')
      b = 0
      imgs = []
      for img in images
        imgs[b] = img[:src]
        b += 1
      end
      furl = '<a href="' + furl + '" target="_blank">' + furl + '</a>'
      aucid = doc.xpath('//dd[@class="ProductDetail__description"]/text()')[10].inner_text
      seller = doc.xpath('//span[@class="Seller__name"]/a')[0].inner_text
      pfb = doc.xpath('//span[@class="Seller__ratingGood"]')[0].inner_text
      nfb = doc.xpath('//span[@class="Seller__ratingBad"]')[0].inner_text
    end

    #利益などの計算

    result = [
      image,
      surl,
      keyword,
      maxPrice,
      avgPrice,
      "",
      furl,
      title,
      aucid,
      cPrice,
      bPrice,
      seller,
      pfb,
      nfb
    ];

    maxnumber = 5
    if furl != nil && furl != "" then
      for p in 0..maxnumber
        if p > imgs.length then
          result.push("")
        else
          result.push(imgs[p])
        end
      end
    else
      for p in 0..maxnumber
        result.push("")
      end
    end
    render json:result
  end

  def mount
    if request.post? then
      cuser = current_user.email
      res = params[:data]
      regasin = JSON.parse(res[:regasin])
      ngasin = JSON.parse(res[:ngasin])
      logger.debug(regasin)
      list = Asin.where(user:cuser)
      if list != nil then
        for j in 0..regasin.length - 1
          reglist = list.find_by(rasin: regasin[j][0])
          if reglist == nil then
            Asin.create(
              user: cuser,
              rasin: regasin[j][0]
            )
          end
        end

        for j in 0..ngasin.length - 1
          nglist = list.find_by(nasin: ngasin[j][0])
          if nglist == nil then
            Asin.create(
              user: cuser,
              nasin: ngasin[j][0]
            )
          end
        end

      else
        for j in 0..regasin.length - 1
          Asin.create(
            user: cuser,
            rasin: regasin[j][0]
          )
        end
        for j in 0..ngasin.length - 1
          Asin.create(
            user: cuser,
            nasin: ngasin[j][0]
          )
        end
      end
    end
    render json: nil
  end

  def setup

    if request.post? then
      cuser = current_user.email
      surl = URI("https://auctions.yahoo.co.jp/search/search?")
      info = params
      info = info.delete("authenticity_token")
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
    end
  end

  def save
    if request.post? then
      cuser = current_user.email
      list = params[:data]
      list = JSON.parse(list)
      account = Fvalue.find_by(user:cuser)

      if account != nil then
        account.update(
          user: cuser,
          list: list
        )
      else
        Fvalue.create(
          user: cuser,
          list: list
        )
      end
    end
  end

  def clear
    if request.post? then
      target = Asin.all.delete_all
    end
    redirect_to '/items/show#tab_d'
  end

  private def CCur(value)
    res = value.gsub(/\,/,"")
    res = res.gsub(/円/,"")
    res = res.gsub(/ /,"")
    res = res.to_i
    return res
  end

end
