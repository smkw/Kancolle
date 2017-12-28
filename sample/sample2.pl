#! /usr/bin/perl -w

use strict;
use warnings;
no warnings 'redefine';
use IO::File;
use lib 'lib';
use HTTP::Proxy;
use HTTP::Proxy::BodyFilter::complete;
use HTTP::Proxy::BodyFilter::simple;
use JSON;
use Data::Dumper;
use utf8;

# Data::DumperでUTF-8文字列をエスケープさせないための処理
*Data::Dumper::qquote = sub {
    my $str = shift;
    $str =~ s/'/\\'/g;
    return "'" . $str . "'"
};

# JSONログ出力処理
sub logging {

    my ($api_path, $json) = @_;

    # 現在日時
    my $nowtime = time;
    my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($nowtime))[0, 1, 2, 3, 4, 5];
    # ログファイル出力ディレクトリ
    my $outputdir = sprintf 'logs/%d-%02d-%02d', $year + 1900, $mon + 1, $mday;
    # ログファイル名
    my $filename = sprintf '%02d%02d%02d-%s.txt', $hour, $min, $sec, $api_path;
    # 年月日別ディレクトリがなければ作成
    mkdir $outputdir, 0700 unless -d $outputdir;
    my $logfilename = $outputdir . '/' . $filename;

    my $fh = IO::File->new($logfilename, '>');
    if (defined $fh) {
        binmode $fh, ':utf8';
        # ハッシュ変数に格納されたJSONをダンプ
        my $dumper = Data::Dumper->new([$json]);
        $dumper->Indent(1);
        $dumper->Terse(1);
        $dumper->Useqq(0);
        $dumper->Pair(':');
        $dumper->Useperl(1);
        $dumper->Sortkeys(1);
        print $fh $dumper->Dump;
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
          sub {
              # サーバーから返されるコンテンツに対する処理
              shift;
              my ($text, $msg) = @_;
              if (defined $$text && $$text) {
                  my $str = $$text;
                  # APIのURIを取得
                  my @paths = (split('/', $msg->{_request}->{_uri}))[4, 5];
                  # 先頭の"svdata="を除去
                  if ($str =~ s/^svdata=// && $paths[0]) {
                      my $json;
                      # JSONをデコードしハッシュ変数に格納
                      eval { $json = decode_json($str) };
                      unless ($@) {
                          # JSONデコードに成功したらログ記録
                          my $api_path = $paths[0];
                          $api_path .= '-' . $paths[1] if $paths[1];
                          logging($api_path, $json);
                      }
                  }
              }
          }
        )
    );

    $proxy->start;
}
