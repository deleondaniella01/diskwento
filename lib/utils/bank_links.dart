// filepath: /Users/dmdeleon/Applications/diskwento/lib/utils/bank_links.dart
String getBankSourceLink(String? bank) {
  switch ((bank ?? '').toUpperCase()) {
    case 'BPI':
      return 'https://www.bpi.com.ph/personal/rewards-and-promotions/promos?tab=Credit_cards';
    case 'RCBC':
      return 'https://rcbccredit.com/promos';
    case 'BDO':
      return 'https://www.deals.bdo.com.ph/catalog-page?type=credit-card';
    case 'METROBANK':
      return 'https://www.metrobank.com.ph/promos/credit-card-promos';
    case 'SECURITY BANK':
      return 'https://www.securitybank.com/promos/';
    case 'UNIONBANK':
      return 'https://www.unionbankph.com/cards/credit-card/discounts-and-promos';
    default:
      return '';
  }
}