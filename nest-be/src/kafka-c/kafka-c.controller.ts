import { Controller, Post, Body } from '@nestjs/common';
import { KafkaCService } from './kafka-c.service';

class SendMessageDto {
  msg: string;
}

@Controller('kafka-c')
export class KafkaCController {
  constructor(private readonly kafkaCService: KafkaCService) {}

  @Post('message')
  async sendMessage(@Body() body: SendMessageDto) {
    await this.kafkaCService.queueMessage(body.msg);
    return { success: true, queued: body.msg };
  }
}
