#!/usr/bin/env python
# -*- coding: UTF-8 -*-
import feedparser, re, csv, json, io, time
alldata = {}
feed = feedparser.parse('http://minjust.ru/ru/extremist-materials/rss')['entries']
writer = csv.writer(open('fedspisok.csv', 'w'))
for string in feed:
  if string.description != '' and re.search(ur'(Материал(ы|)|Запись) исключен(ы|а|) из списка', string.description) is None:
    value_regex = re.search(ur'^(.+?[А-яA-z»\d\"])[^А-яA-z»\d\"]*((заочное|апелляционное|кассационное|)[^А-я](((Р|р)ешени(я|е))|постановление|определение|приговор).+[А-я])\s*(\d[\d\.\s]+\d)[^\d]*$', string.description.replace('\n','').replace(u' Решением Московского районного суда г. Казани от 17.09.2010 экстремистским материалом признана брошюра «Аль-Ваъй» № 219.',''))
    number = re.search(ur'^(Материал #)(\d+)', string.title).group(2)
    if value_regex is not None:
      title = ' '.join(value_regex.groups()[0].strip().split())
      date_original = value_regex.groups()[7].replace(' ','').replace('1012', '2012')
      date = time.strftime('%Y-%m-%d', time.strptime(date_original, '%d.%m.%Y'))
      court = ' '.join(value_regex.groups()[1].strip().replace('(','').split()) + ' ' + date_original
      alldata[number] = {'title': title, 'date': date, 'court': court, 'link': string.link}
      writer.writerow([number, title.encode("utf-8"), date, court.encode("utf-8"), string.link])
    else:
      alldata[number] = {'title': string, 'date': '', 'court': '', 'link': string.link}
      writer.writerow([number, string.description.encode("utf-8"),'' ,'' , string.link])
      
with io.open('fedspisok.json', 'w', encoding='utf-8') as f:
  f.write(unicode(json.dumps(alldata, ensure_ascii=False)))
