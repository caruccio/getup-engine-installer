#resource "aws_route53_record" "masters-SRV" {
#    zone_id = "${data.aws_route53_zone.cluster.id}"
#    name    = "masters.${var.cluster_zone}"
#    type    = "SRV"
#    records = ["${formatlist("1 10 9100 %s", aws_route53_record.masters.*.name)}"]
#    ttl     = "300"
#}
