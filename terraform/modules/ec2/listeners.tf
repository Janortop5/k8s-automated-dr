# uncomment this if going with HTTP
resource "aws_lb_listener" "alb_listener_1" {
 load_balancer_arn = aws_lb.alb.arn
 port              = var.alb_listener_1.port
 protocol          = var.alb_listener_1.protocol

 default_action {
   type             = var.alb_listener_1.action_type
   target_group_arn = aws_lb_target_group.alb_target_group.arn
 }
}

## uncomment this if going with HTTPS
# resource "aws_lb_listener" "alb_listener_1" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = var.alb_listener_1.port
#   protocol          = var.alb_listener_1.protocol

#   default_action {
#     type             = var.alb_listener_1.action_type

#     redirect {
#       port        = var.alb_listener_2.port
#       protocol    = var.alb_listener_2.protocol
#       status_code = var.alb_listener_1.status_code
#     }
#   }
# }

# resource "aws_lb_listener" "alb_listener_2" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = var.alb_listener_2.port
#   protocol          = var.alb_listener_2.protocol
#   ssl_policy        = var.alb_listener_2.ssl_policy
#   certificate_arn   = aws_acm_certificate.cert.arn

#   default_action {
#     type             = var.alb_listener_2.action_type
#     target_group_arn = aws_lb_target_group.alb_target_group.arn
#   }

#   depends_on = [
#     aws_acm_certificate_validation.acm_validate
#   ]
# }