#! /usr/bin/perl -w

use strict;
use warnings;
use IO::File;
use lib 'lib';
use HTTP::Proxy;
use HTTP::Proxy::BodyFilter::complete;
use HTTP::Proxy::BodyFilter::simple;

# JSONログ出力処理
sub logging {

    my $json = shift;
    my $fh = IO::File->new('sample1.log', '>>');
    if (defined $fh) {
        print $fh $json;
        undef $fh;
    }
}

# メイン処理
MAIN: {
    # HTTP::Proxyのインスタンス準備
    my $proxy = HTTP::Proxy->new(
      port            => 16666,         # ポート番号
      host            => '127.0.0.1',   # プロキシのIPアドレス
      timeout         => 30,            # タイムアウト (秒)
      via             => '',            # 環境変数HTTP_VIAは出力しない
      x_forwarded_for => 0,             # 環境変数HTTP_FORWARDED_FORは出力しない
      max_clients     => 150            # 同時接続数
    );

    $proxy->push_filter(
        scheme      => 'http',          # プロキシ処理の対象とするプロトコル
        mime        => 'text/*',        # プロキシ処理の対象とするMIME-Type
        path        => '/kcsapi/',      # プロキシ処理の対象とするURIのPath
        response    => HTTP::Proxy::BodyFilter::complete->new,
        response    => HTTP::Proxy::BodyFilter::simple->new(
          sub{
              # サーバーから返されるコンテンツに対する処理
              shift;
              my ($text, $msg) = @_;
              if (defined $$text && $$text) {
                  logging($$text);
              }
          }
        )
    );

    $proxy->start;
}
